import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipo_allotment_tracker/data/models/app_backup.dart';
import 'package:ipo_allotment_tracker/data/models/ipo.dart';
import 'package:ipo_allotment_tracker/data/models/ipo_application.dart';
import 'package:ipo_allotment_tracker/data/models/pan_profile.dart';

void main() {
  const codec = AppBackupCodec();

  AppBackup createBackup() => AppBackup(
    exportedAt: DateTime.utc(2026, 9, 5, 10, 30),
    profiles: const [
      PanProfile(
        id: 'profile-1',
        name: 'Primary',
        maskedPan: '*****1234F',
        isDefault: true,
      ),
    ],
    pansByProfileId: const {'profile-1': 'ABCDE1234F'},
    applications: [
      IpoApplication(
        id: 'application-1',
        ipoId: 'ipo-1',
        panProfileId: 'profile-1',
        addedAt: DateTime.utc(2026, 9, 1),
        status: ApplicationStatus.allotted,
        allottedShares: 12,
      ),
    ],
    cachedIpos: [
      Ipo(
        id: 'ipo-1',
        name: 'Example Industries',
        symbol: 'EXAMPLE',
        type: IpoType.mainboard,
        status: IpoStatus.closed,
        issueType: 'IPO',
        minPrice: 100,
        maxPrice: 105,
        lotSize: 12,
        openDate: DateTime.utc(2026, 8, 20),
        closeDate: DateTime.utc(2026, 8, 22),
        allotmentDate: DateTime.utc(2026, 8, 25),
        listingDate: DateTime.utc(2026, 8, 28),
        registrarName: 'Example Registrar',
        registrarCode: 'EXAMPLE',
      ),
    ],
    themeMode: 'dark',
    discoverIpoType: 'mainboard',
    lastIpoRefresh: DateTime.utc(2026, 9, 5, 9),
    processedNotificationTriggers: const {
      'trigger-1': '2026-09-05T09:15:00.000Z',
    },
  );

  test(
    'round trip preserves all restorable data and exports plaintext PAN',
    () {
      final encoded = codec.encode(createBackup());
      final decodedJson = jsonDecode(encoded) as Map<String, dynamic>;
      final data = decodedJson['data'] as Map<String, dynamic>;
      final profiles = data['panProfiles'] as List<dynamic>;

      expect((profiles.single as Map<String, dynamic>)['pan'], 'ABCDE1234F');
      expect(decodedJson['containsPlaintextPan'], isTrue);

      final restored = codec.decode(encoded);
      expect(restored.pansByProfileId['profile-1'], 'ABCDE1234F');
      expect(restored.profiles.single.maskedPan, '*****1234F');
      expect(restored.applications.single.allottedShares, 12);
      expect(restored.cachedIpos.single.name, 'Example Industries');
      expect(restored.themeMode, 'dark');
      expect(restored.discoverIpoType, 'mainboard');
      expect(restored.processedNotificationTriggers, hasLength(1));
    },
  );

  test('rejects a backup containing an invalid PAN', () {
    final raw =
        jsonDecode(codec.encode(createBackup())) as Map<String, dynamic>;
    final data = raw['data'] as Map<String, dynamic>;
    final profiles = data['panProfiles'] as List<dynamic>;
    (profiles.single as Map<String, dynamic>)['pan'] = 'NOT-A-PAN';

    expect(
      () => codec.decode(jsonEncode(raw)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects backup versions newer than the app supports', () {
    final raw =
        jsonDecode(codec.encode(createBackup())) as Map<String, dynamic>;
    raw['schemaVersion'] = AppBackup.schemaVersion + 1;

    expect(
      () => codec.decode(jsonEncode(raw)),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.message,
          'message',
          contains('newer app version'),
        ),
      ),
    );
  });
}
