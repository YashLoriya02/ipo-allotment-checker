import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_notification_listener_plus/flutter_notification_listener_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/allotment_check_result.dart';
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import 'allotment_registrar_service.dart';
import 'local_notification_service.dart';
import 'local_storage_service.dart';
import 'secure_storage_service.dart';

class IpoPremiumNotificationListenerService {
  IpoPremiumNotificationListenerService._();

  static final IpoPremiumNotificationListenerService instance =
      IpoPremiumNotificationListenerService._();

  // static const String ipoPremiumPackage = 'com.example.app'; // for testing in emulator
  static const String ipoPremiumPackage = 'com.ipopremium.app';
  static const String _uiPortName = 'ipo_premium_automation_updates';

  final RxBool hasNotificationAccess = false.obs;
  final RxBool listenerRunning = false.obs;

  ReceivePort? _uiPort;
  final StreamController<IpoApplication> _applicationUpdates =
      StreamController<IpoApplication>.broadcast();
  bool _initialized = false;

  Stream<IpoApplication> get applicationUpdates => _applicationUpdates.stream;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!_isAndroid || _initialized) return;

    await NotificationsListener.initialize(
      callbackHandle: ipoPremiumNotificationBackgroundCallback,
    );

    _registerUiPort();
    _initialized = true;
    await refreshAndStartIfAllowed();
  }

  Future<void> refreshAndStartIfAllowed() async {
    if (!_isAndroid) return;

    final granted = await NotificationsListener.hasPermission ?? false;
    hasNotificationAccess.value = granted;

    if (!granted) {
      listenerRunning.value = false;
      return;
    }

    var running = await NotificationsListener.isRunning ?? false;
    if (!running) {
      // No persistent foreground notification for now. Notification listener
      // access itself is enough for normal operation after the app has been
      // opened. We can add reboot/foreground hardening later if required.
      await NotificationsListener.startService(foreground: false);
      running = await NotificationsListener.isRunning ?? false;
    }

    listenerRunning.value = running;
  }

  Future<void> openNotificationAccessSettings() async {
    if (!_isAndroid) return;
    await NotificationsListener.openPermissionSettings();
  }

  void _registerUiPort() {
    IsolateNameServer.removePortNameMapping(_uiPortName);
    _uiPort?.close();
    _uiPort = ReceivePort();
    IsolateNameServer.registerPortWithName(_uiPort!.sendPort, _uiPortName);

    _uiPort!.listen((message) {
      if (message is! Map || message['type'] != 'application_updated') {
        return;
      }

      final rawApplication = message['application'];
      if (rawApplication is! Map) return;

      try {
        _applicationUpdates.add(
          IpoApplication.fromJson(Map<String, dynamic>.from(rawApplication)),
        );
      } catch (_) {
        // Background persistence remains the source of truth even if a UI
        // refresh signal is malformed.
      }
    });
  }

  static void notifyUiApplicationChanged(IpoApplication application) {
    IsolateNameServer.lookupPortByName(_uiPortName)?.send(<String, dynamic>{
      'type': 'application_updated',
      'application': application.toJson(),
    });
  }
}

/// Called by flutter_notification_listener_plus in its background Flutter
/// engine. It must stay a top-level/static entry point for release builds.
@pragma('vm:entry-point')
void ipoPremiumNotificationBackgroundCallback(NotificationEvent event) {
  unawaited(IpoPremiumNotificationAutomation.handle(event));
}

abstract class IpoPremiumNotificationAutomation {
  static const Duration _recentCheckGuard = Duration(minutes: 5);

  static final RegExp _allotmentReadyPattern = RegExp(
    r'\ballotment\b.{0,70}\b(out|declared|released|available|published|finalized|finalised|announced|live)\b'
    r'|\b(out|declared|released|available|published|finalized|finalised|announced|live)\b.{0,70}\ballotment\b',
    caseSensitive: false,
  );

  @pragma('vm:entry-point')
  static Future<void> handle(NotificationEvent event) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      final packageName = event.packageName?.trim() ?? '';

      debugPrint('[IPO_NOTI] received event: $event');

      if (kDebugMode) {
        // Intentionally log only the package name, never notification content.
        debugPrint('[IPO_NOTI] received package=$packageName');
      }

      final isAcceptedPackage = await _isAcceptedPackage(packageName);
      if (!isAcceptedPackage) {
        return;
      }

      if (kDebugMode) {
        final source =
            packageName ==
                IpoPremiumNotificationListenerService.ipoPremiumPackage
            ? 'ipo-premium'
            : 'debug-app';
        debugPrint('[IPO_NOTI] accepted source=$source');
      }

      final notificationText = _combinedNotificationText(event);
      if (!_looksLikeAllotmentReady(notificationText)) {
        if (kDebugMode) {
          debugPrint(
            '[IPO_NOTI] IPO Premium notification ignored: not allotment-ready',
          );
        }
        return;
      }

      await GetStorage.init('ipo_tracker');

      final storage = LocalStorageService();
      final applications = storage.readApplications();
      final profiles = storage.readProfiles();

      final profileById = {for (final profile in profiles) profile.id: profile};

      if (applications.isEmpty) return;

      final cachedIpos = storage.readCachedIpos();
      final ipoById = {for (final ipo in cachedIpos) ipo.id: ipo};

      final matchingIpoIds = _matchActiveIpos(
        notificationText: notificationText,
        applications: applications,
        ipoById: ipoById,
      );

      if (matchingIpoIds.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[IPO_NOTI] allotment notification did not match an active IPO',
          );
        }
        return;
      }

      // Claim only after the notification has passed both filters and matched
      // one of the user's active IPOs. This avoids suppressing a later useful
      // update that reuses the same Android notification ID.
      final eventKey = _eventKey(event, notificationText);
      final claimed = await storage.claimNotificationTrigger(eventKey);
      if (!claimed) {
        if (kDebugMode) {
          debugPrint('[IPO_NOTI] duplicate IPO Premium notification ignored');
        }
        return;
      }

      final secureStorage = SecureStorageService();
      final allotmentRegistrar = AllotmentRegistrarService();
      for (final ipoId in matchingIpoIds) {
        final ipo = ipoById[ipoId];
        if (ipo == null || !allotmentRegistrar.supportsRegistrar(ipo)) {
          continue;
        }

        // Bigshare is intentionally manual. Never attempt a background PAN
        // lookup. Surface one actionable notification per active PAN profile;
        // tapping it opens Bigshare's own frontend inside the app.
        if (allotmentRegistrar.isBigshare(ipo)) {
          for (final application in applications) {
            if (application.ipoId != ipoId || application.isCompleted) continue;

            final profile = profileById[application.panProfileId];
            try {
              await LocalNotificationService.instance
                  .showBigshareManualCheckRequired(
                ipo: ipo,
                application: application,
                profileName: profile?.name,
                requestPermission: false,
              );
            } catch (_) {
              // The source IPO Premium alert has already been claimed. Failure
              // to display our follow-up must not alter application state.
            }
          }
          continue;
        }

        for (var index = 0; index < applications.length; index++) {
          final application = applications[index];
          if (application.ipoId != ipoId || application.isCompleted) continue;

          final lastChecked = application.lastCheckedAt;
          if (lastChecked != null &&
              DateTime.now().difference(lastChecked).abs() <
                  _recentCheckGuard) {
            continue;
          }

          final pan = await secureStorage.readPan(application.panProfileId);
          if (pan == null || pan.trim().isEmpty) continue;

          IpoApplication updated;

          try {
            final result = await allotmentRegistrar.checkAllotment(
              ipo: ipo,
              pan: pan,
              skipAllotmentDateGuard: true,
            );

            updated = application.copyWith(
              status: _mapStatus(result.status),
              lastCheckedAt: DateTime.now(),
              allottedShares: result.sharesAllotted,
              applicationNumber: result.applicationNumber,
              lastMessage: result.message,
              clearAllottedShares: result.sharesAllotted == null,
              clearApplicationNumber: result.applicationNumber == null,
              clearLastMessage: result.message == null,
            );
          } on AllotmentRegistrarException catch (error) {
            updated = application.copyWith(
              status: ApplicationStatus.temporaryError,
              lastCheckedAt: DateTime.now(),
              lastMessage: error.message,
            );
          } catch (_) {
            updated = application.copyWith(
              status: ApplicationStatus.temporaryError,
              lastCheckedAt: DateTime.now(),
              lastMessage: 'The registrar could not be reached right now.',
            );
          }

          applications[index] = updated;
          await storage.writeApplications(applications);
          IpoPremiumNotificationListenerService.notifyUiApplicationChanged(
            updated,
          );

          final profile = profileById[application.panProfileId];

          try {
            await LocalNotificationService.instance.showAllotmentResult(
              ipo: ipo,
              application: updated,
              profileName: profile?.name,
              automatic: true,
              requestPermission: false,
            );
          } catch (_) {
            // Persisting the allotment result is more important than the local
            // notification. Never roll back because notification display failed.
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[IPO_NOTI] automation failed: ${error.runtimeType}');
      }
    }
  }

  static String? _debugOwnPackageName;

  /// Production accepts only IPO Premium. In debug builds we additionally
  /// accept notifications posted by this app itself so the full listener flow
  /// can be exercised on an emulator without waiting for a real IPO alert.
  static Future<bool> _isAcceptedPackage(String packageName) async {
    debugPrint(
      '[IPO_NOTI] checking package=$packageName | debugOwn=${IpoPremiumNotificationListenerService.ipoPremiumPackage}',
    );

    if (packageName ==
        IpoPremiumNotificationListenerService.ipoPremiumPackage) {
      return true;
    }

    if (!kDebugMode || packageName.isEmpty) {
      return false;
    }

    try {
      _debugOwnPackageName ??= (await PackageInfo.fromPlatform()).packageName;
      return packageName == _debugOwnPackageName;
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeAllotmentReady(String text) {
    if (text.isEmpty) return false;

    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    const explicitPhrases = <String>[
      'allotment is out',
      'allotment out',
      'allotment status is out',
      'allotment status out',
      'allotment result is out',
      'allotment results are out',
      'allotment result out',
      'allotment has been declared',
      'allotment declared',
      'allotment result declared',
      'allotment released',
      'allotment result released',
      'allotment available',
      'allotment status available',
      'allotment finalized',
      'allotment finalised',
      'allotment announced',
      'allotment result announced',
      'allotment is live',
      'allotment result is live',
    ];

    if (explicitPhrases.any(normalized.contains)) return true;
    return _allotmentReadyPattern.hasMatch(normalized);
  }

  static String _combinedNotificationText(NotificationEvent event) {
    final pieces = <String>[];

    void add(dynamic value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) pieces.add(text);
    }

    add(event.title);
    add(event.text);

    final customViewTexts = event.customViewTexts;
    if (customViewTexts != null) {
      for (final line in customViewTexts) {
        add(line);
      }
    }

    final raw = event.raw;
    if (raw is Map) {
      add(raw['subText']);
      add(raw['summaryText']);

      final textLines = raw['textLines'];
      if (textLines is Iterable) {
        for (final line in textLines) {
          add(line);
        }
      }

      final customViewTexts = raw['customViewTexts'];
      if (customViewTexts is Iterable) {
        for (final line in customViewTexts) {
          add(line);
        }
      }
    }

    return pieces.join(' ');
  }

  static String _eventKey(NotificationEvent event, String notificationText) {
    final stable = event.key?.trim();
    final unique = event.uniqueId?.trim();
    final base = stable != null && stable.isNotEmpty
        ? stable
        : (unique != null && unique.isNotEmpty
              ? unique
              : '${event.packageName}:${event.id}');

    // Include post time and a deterministic text fingerprint. IPO Premium may
    // reuse a notification ID/key for later updates; those must still be able
    // to trigger a fresh allotment check.
    return '$base:${event.timestamp}:${_stableTextHash(notificationText)}';
  }

  static int _stableTextHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static Set<String> _matchActiveIpos({
    required String notificationText,
    required List<IpoApplication> applications,
    required Map<String, Ipo> ipoById,
  }) {
    final normalizedNotification = _normalize(notificationText);
    final notificationTokens = _meaningfulTokens(normalizedNotification);
    final matches = <String>{};

    for (final application in applications) {
      if (application.isCompleted) continue;

      final ipo = ipoById[application.ipoId];
      if (ipo == null) continue;

      final fullName = _normalize(ipo.name);
      final shortName = _normalize(_stripLegalSuffixes(ipo.name));
      final symbol = _normalize(ipo.symbol);

      // Strong matches first: full/clean company name or stock symbol appears
      // directly in the notification.
      if ((fullName.length >= 5 && normalizedNotification.contains(fullName)) ||
          (shortName.length >= 5 &&
              normalizedNotification.contains(shortName)) ||
          _containsToken(normalizedNotification, symbol)) {
        matches.add(ipo.id);
        continue;
      }

      // IPO Premium may shorten a company name, e.g. "MILKY MIST IPO" for
      // "MILKY MIST DAIRY FOOD LIMITED". Allow a conservative token-overlap
      // match, requiring at least two meaningful company words and >= 50% of
      // the company's meaningful tokens to be present.
      final companyTokens = _meaningfulTokens(shortName);
      if (companyTokens.length < 2) continue;

      final overlap = companyTokens.intersection(notificationTokens).length;
      final coverage = overlap / companyTokens.length;

      if (overlap >= 2 && coverage >= 0.50) {
        matches.add(ipo.id);
      }
    }

    return matches;
  }

  static bool _containsToken(String haystack, String token) {
    if (token.length < 3) return false;
    return RegExp(
      '(?:^|\\s)${RegExp.escape(token)}(?:\\s|\$)',
    ).hasMatch(haystack);
  }

  static Set<String> _meaningfulTokens(String value) {
    const ignored = <String>{
      'IPO',
      'LIMITED',
      'LTD',
      'PRIVATE',
      'PVT',
      'INDIA',
      'THE',
      'AND',
    };

    return value
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.length >= 3 && !ignored.contains(part))
        .toSet();
  }

  static String _stripLegalSuffixes(String value) {
    return value
        .replaceAll(RegExp(r'\bPRIVATE\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bPVT\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bLIMITED\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bLTD\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bIPO\b', caseSensitive: false), ' ');
  }

  static String _normalize(String value) {
    var normalized = value.toUpperCase().trim();
    normalized = normalized.replaceAll('&', ' AND ');
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\bLTD\b'), 'LIMITED');
    normalized = normalized.replaceAll(RegExp(r'\bIPO\b'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.trim();
  }

  static ApplicationStatus _mapStatus(AllotmentApiStatus status) {
    return switch (status) {
      AllotmentApiStatus.allotted => ApplicationStatus.allotted,
      AllotmentApiStatus.notAllotted => ApplicationStatus.notAllotted,
      AllotmentApiStatus.noRecord => ApplicationStatus.noRecord,
      AllotmentApiStatus.notLive => ApplicationStatus.resultNotLive,
      AllotmentApiStatus.humanRequired => ApplicationStatus.humanRequired,
      AllotmentApiStatus.temporaryError => ApplicationStatus.temporaryError,
      AllotmentApiStatus.unsupportedRegistrar =>
        ApplicationStatus.unsupportedRegistrar,
      AllotmentApiStatus.unknown => ApplicationStatus.unknown,
    };
  }
}
