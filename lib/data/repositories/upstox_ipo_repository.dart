import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/token.dart';
import '../models/ipo.dart';
import '../services/local_storage_service.dart';
import 'ipo_repository.dart';

class UpstoxIpoRepository implements IpoRepository {
  UpstoxIpoRepository({String token = UPSTOX_ANALYTICS_TOKEN})
    : _token = token.trim(),
      _storage = Get.find<LocalStorageService>();

  static const _baseUrl = 'https://api.upstox.com/v2';
  static const _pageSize = 30;

  final String _token;
  final LocalStorageService _storage;
  final GetConnect _client = GetConnect(timeout: const Duration(seconds: 25));
  final Map<String, Ipo> _detailsCache = <String, Ipo>{};

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  @override
  Future<List<Ipo>> getIpos() async {
    _ensureConfigured();

    final groups = await Future.wait(IpoStatus.values.map(_getIposByStatus));
    final items = groups.expand((group) => group).toList();

    final persisted = <String, Ipo>{
      for (final ipo in _storage.readCachedIpos()) ipo.id: ipo,
    };

    final byId = <String, Ipo>{};
    for (final ipo in items) {
      final cached = persisted[ipo.id];
      byId[ipo.id] = cached?.isDetailed == true
          ? ipo.mergeDetailsFrom(cached!)
          : ipo;
    }

    return List<Ipo>.unmodifiable(byId.values);
  }

  @override
  Future<Ipo?> getById(String id) async {
    _ensureConfigured();

    final memoryCached = _detailsCache[id];
    if (memoryCached != null) return memoryCached;

    final persistedFallback = _storage.readCachedIpoById(id);

    try {
      final response = await _client.get(
        '$_baseUrl/ipos/${Uri.encodeComponent(id)}',
        headers: _headers,
      );

      final body = _validatedBody(response, context: 'IPO details');
      final data = body['data'];
      if (data is! Map) return persistedFallback;

      final ipo = _mapIpo(Map<String, dynamic>.from(data), isDetailed: true);

      _detailsCache[id] = ipo;
      await _storage.upsertCachedIpo(ipo);
      return ipo;
    } catch (error) {
      if (persistedFallback != null) {
        debugPrint('Upstox detail refresh failed; using local cache: $error');
        return persistedFallback;
      }
      rethrow;
    }
  }

  Future<List<Ipo>> _getIposByStatus(IpoStatus status) async {
    final items = <Ipo>[];
    var pageNumber = 1;
    var totalPages = 1;

    do {
      final response = await _client.get(
        '$_baseUrl/ipos',
        headers: _headers,
        query: {
          'status': _statusToApi(status),
          'page_number': '$pageNumber',
          'records': '$_pageSize',
        },
      );

      final body = _validatedBody(
        response,
        context: '${_statusToApi(status)} IPOs',
      );

      final data = body['data'];
      if (data is List) {
        for (final raw in data) {
          if (raw is Map) {
            items.add(
              _mapIpo(Map<String, dynamic>.from(raw), isDetailed: false),
            );
          }
        }
      }

      final metaData = body['meta_data'];
      if (metaData is Map) {
        final page = metaData['page'];
        if (page is Map) {
          totalPages = _asInt(page['total_pages']) ?? 1;
        }
      }

      pageNumber++;
    } while (pageNumber <= totalPages);

    return items;
  }

  Map<String, dynamic> _validatedBody(
    Response<dynamic> response, {
    required String context,
  }) {
    if (!response.isOk) {
      final upstream = _extractErrorMessage(response.body);
      final message =
          upstream ??
          (response.statusCode == null
              ? 'Could not connect to Upstox. Check your internet connection and try again.'
              : 'Unable to fetch $context from Upstox (${response.statusCode}).');
      throw UpstoxIpoException(message, statusCode: response.statusCode);
    }

    final body = response.body;
    if (body is! Map) {
      throw UpstoxIpoException(
        'Upstox returned an invalid response for $context.',
        statusCode: response.statusCode,
      );
    }

    final normalized = Map<String, dynamic>.from(body);
    if (normalized['status'] != 'success') {
      throw UpstoxIpoException(
        _extractErrorMessage(normalized) ?? 'Upstox could not return $context.',
        statusCode: response.statusCode,
      );
    }

    return normalized;
  }

  Ipo _mapIpo(Map<String, dynamic> data, {required bool isDetailed}) {
    final timelineRaw = data['timeline'];
    final timeline = timelineRaw is Map
        ? Map<String, dynamic>.from(timelineRaw)
        : const <String, dynamic>{};

    final registrarRaw = data['registrar_info'];
    final registrar = registrarRaw is Map
        ? Map<String, dynamic>.from(registrarRaw)
        : const <String, dynamic>{};

    return Ipo(
      id: _asString(data['id']) ?? '',
      name: _asString(data['name']) ?? 'Unknown IPO',
      symbol: _asString(data['symbol']) ?? '',
      type: _parseType(data['issue_type']),
      status: _parseStatus(data['status']),
      issueType: 'IPO',
      minPrice: _positiveDouble(data['minimum_price']),
      maxPrice: _positiveDouble(data['maximum_price']),
      lotSize: _asInt(data['lot_size']),
      openDate: _parseDate(
        timeline['application_start_date'] ?? data['bidding_start_date'],
      ),
      closeDate: _parseDate(
        timeline['application_end_date'] ?? data['bidding_end_date'],
      ),
      allotmentDate: _parseDate(timeline['allotment_date']),
      listingDate: _parseDate(timeline['listing_date']),
      registrarName: _asString(registrar['name']),
      registrarCode: _asString(registrar['registrar']),
      issueSizeCrore: _positiveDouble(data['issue_size']),
      industry: _asString(data['industry']),
      totalSubscription: _asDouble(data['total_subscription']),
      listingPrice: _positiveDouble(data['listing_price']),
      listingExchange: _asString(data['listing_exchange']),
      cutOffPrice: _positiveDouble(data['cut_off_price']),
      isDetailed: isDetailed,
    );
  }

  void _ensureConfigured() {
    if (_token.isEmpty) {
      throw const UpstoxIpoException(
        'Upstox Analytics Token is not configured.',
      );
    }
  }

  IpoStatus _parseStatus(dynamic raw) =>
      switch (_asString(raw)?.toLowerCase()) {
        'upcoming' => IpoStatus.upcoming,
        'closed' => IpoStatus.closed,
        'listed' => IpoStatus.listed,
        _ => IpoStatus.open,
      };

  IpoType _parseType(dynamic raw) =>
      _asString(raw)?.toLowerCase() == 'sme' ? IpoType.sme : IpoType.mainboard;

  String _statusToApi(IpoStatus status) => switch (status) {
    IpoStatus.open => 'open',
    IpoStatus.upcoming => 'upcoming',
    IpoStatus.closed => 'closed',
    IpoStatus.listed => 'listed',
  };

  DateTime? _parseDate(dynamic raw) {
    final value = _asString(raw);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String? _asString(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  double? _asDouble(dynamic raw) {
    return raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  }

  double? _positiveDouble(dynamic raw) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return null;
    return value;
  }

  String? _extractErrorMessage(dynamic raw) {
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final direct = _asString(map['message']);
    if (direct != null) return direct;

    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      final first = Map<String, dynamic>.from(errors.first as Map);
      return _asString(first['message']) ?? _asString(first['errorCode']);
    }

    return null;
  }
}

class UpstoxIpoException implements Exception {
  const UpstoxIpoException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
