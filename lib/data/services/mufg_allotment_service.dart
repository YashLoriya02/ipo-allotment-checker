import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../models/allotment_check_result.dart';
import '../models/ipo.dart';

class MufgAllotmentService extends GetxService {
  static final Uri _publicIssuesUri = Uri.parse(
    'https://in.mpms.mufg.com/Initial_Offer/public-issues.html',
  );
  static final Uri _getDetailsUri = Uri.parse(
    'https://in.mpms.mufg.com/Initial_Offer/IPO.aspx/GetDetails',
  );
  static final Uri _generateTokenUri = Uri.parse(
    'https://in.mpms.mufg.com/Initial_Offer/IPO.aspx/generateToken',
  );
  static final Uri _searchOnPanUri = Uri.parse(
    'https://in.mpms.mufg.com/Initial_Offer/IPO.aspx/SearchOnPan',
  );

  static const Duration _timeout = Duration(seconds: 25);
  static const String _origin = 'https://in.mpms.mufg.com';
  static const String _referer =
      'https://in.mpms.mufg.com/Initial_Offer/public-issues.html';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36';

  bool supportsRegistrar(Ipo ipo) {
    final registrar = '${ipo.registrarCode ?? ''} ${ipo.registrarName ?? ''}'
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim();
    final compact = registrar.replaceAll(' ', '');

    return registrar.contains('MUFG') ||
        compact.contains('LINKINTIME') ||
        compact.contains('INTIMEINDIA');
  }

  Future<AllotmentCheckResult> checkAllotment({
    required Ipo ipo,
    required String pan,
    bool skipAllotmentDateGuard = false,
  }) async {
    if (!supportsRegistrar(ipo)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unsupportedRegistrar,
        message: 'This registrar is not supported yet.',
      );
    }

    if (!skipAllotmentDateGuard && _isBeforeAllotmentDate(ipo.allotmentDate)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.notLive,
        message: 'The allotment result is not available yet.',
      );
    }

    final session = _MufgSession();

    try {
      final companiesXml = await session.getDetailsWithBootstrap();
      final companies = _parseCompanies(companiesXml);
      final company = _findCompany(companies, ipo.name);

      if (company == null) {
        return _result(
          ipo: ipo,
          status: AllotmentApiStatus.notLive,
          message: 'This IPO is not currently available in MUFG allotment status.',
        );
      }

      final token = await session.postForDValue(_generateTokenUri);
      if (token.trim().isEmpty) {
        throw const MufgAllotmentException(
          'MUFG could not generate a verification token.',
        );
      }

      final resultXml = await session.postForDValue(
        _searchOnPanUri,
        payload: <String, String>{
          'clientid': company.id,
          'PAN': pan.trim().toUpperCase(),
          'IFSC': '',
          'CHKVAL': '1',
          'token': token.trim(),
        },
      );

      return _parseSearchResult(
        ipo: ipo,
        xml: resultXml,
      );
    } on MufgAllotmentException {
      rethrow;
    } on SocketException {
      throw const MufgAllotmentException(
        'MUFG could not be reached right now.',
      );
    } on HttpException {
      throw const MufgAllotmentException(
        'MUFG could not complete the request right now.',
      );
    } on FormatException {
      throw const MufgAllotmentException(
        'MUFG returned an unexpected response.',
      );
    } finally {
      session.close();
    }
  }

  AllotmentCheckResult _parseSearchResult({
    required Ipo ipo,
    required String xml,
  }) {
    final trimmed = xml.trim();
    if (trimmed.isEmpty || _looksLikeNoRecord(trimmed)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.noRecord,
        message: 'No allotment record was found for this PAN and IPO.',
      );
    }

    final tables = _tableBlocks(trimmed);
    if (tables.isEmpty) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.noRecord,
        message: 'No allotment record was found for this PAN and IPO.',
      );
    }

    final table = tables.first;
    final allottedShares = _intValue(_tagValue(table, 'ALLOT'));
    final appliedShares = _intValue(_tagValue(table, 'SHARES'));

    if (allottedShares == null) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unknown,
        message: 'Could not determine the allotment status from MUFG.',
      );
    }

    if (allottedShares > 0) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.allotted,
        sharesAllotted: allottedShares,
        message: '$allottedShares shares allotted.',
      );
    }

    return _result(
      ipo: ipo,
      status: AllotmentApiStatus.notAllotted,
      sharesAllotted: 0,
      message: appliedShares == null
          ? 'No shares were allotted.'
          : 'Applied for $appliedShares shares. No shares were allotted.',
    );
  }

  List<_MufgCompany> _parseCompanies(String xml) {
    final companies = <_MufgCompany>[];

    for (final table in _tableBlocks(xml)) {
      final id = _tagValue(table, 'company_id')?.trim();
      final name = _tagValue(table, 'companyname')?.trim();

      if (id == null || id.isEmpty || name == null || name.isEmpty) {
        continue;
      }

      companies.add(_MufgCompany(id: id, name: name));
    }

    return companies;
  }

  _MufgCompany? _findCompany(
    List<_MufgCompany> companies,
    String requestedName,
  ) {
    final requested = _normalizeCompanyName(requestedName);
    if (requested.isEmpty) return null;

    final normalized = <(_MufgCompany, String)>[
      for (final company in companies)
        (company, _normalizeCompanyName(company.name)),
    ];

    for (final item in normalized) {
      if (item.$2 == requested) return item.$1;
    }

    final containmentMatches = normalized
        .where(
          (item) =>
              item.$2.isNotEmpty &&
              (item.$2.contains(requested) || requested.contains(item.$2)),
        )
        .toList();

    if (containmentMatches.length == 1) {
      return containmentMatches.first.$1;
    }

    _MufgCompany? best;
    var bestScore = 0.0;
    var secondBestScore = 0.0;
    final requestedTokens = _companyTokens(requested);

    for (final item in normalized) {
      final candidateTokens = _companyTokens(item.$2);
      if (requestedTokens.isEmpty || candidateTokens.isEmpty) continue;

      final overlap = requestedTokens.intersection(candidateTokens).length;
      final denominator = requestedTokens.length > candidateTokens.length
          ? requestedTokens.length
          : candidateTokens.length;
      final score = overlap / denominator;

      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        best = item.$1;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    // Be conservative: a wrong company match would query the wrong IPO.
    if (best != null &&
        bestScore >= 0.75 &&
        (bestScore - secondBestScore) >= 0.15) {
      return best;
    }

    return null;
  }

  String _normalizeCompanyName(String value) {
    var normalized = value.toUpperCase().trim();
    normalized = normalized.replaceAll('&', ' AND ');
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\bLTD\b'), 'LIMITED');
    normalized = normalized.replaceAll(RegExp(r'\bSME\b'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\bIPO\b'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.trim();
  }

  Set<String> _companyTokens(String value) {
    const ignored = <String>{
      'LIMITED',
      'PRIVATE',
      'PVT',
      'INDIA',
      'THE',
      'AND',
    };

    return value
        .split(' ')
        .where((part) => part.length >= 3 && !ignored.contains(part))
        .toSet();
  }

  List<String> _tableBlocks(String xml) {
    return RegExp(
      r'<Table>(.*?)</Table>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(xml).map((match) => match.group(1) ?? '').toList();
  }

  String? _tagValue(String xml, String tag) {
    final match = RegExp(
      '<${RegExp.escape(tag)}>(.*?)</${RegExp.escape(tag)}>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);

    final value = match?.group(1);
    if (value == null) return null;
    return _decodeXmlEntities(value).trim();
  }

  String _decodeXmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  bool _looksLikeNoRecord(String value) {
    final lower = value.toLowerCase();
    return lower.contains('record not found') ||
        lower.contains('no record found') ||
        lower.contains('no records found');
  }

  int? _intValue(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll(',', '').trim());
  }

  bool _isBeforeAllotmentDate(DateTime? value) {
    if (value == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allotmentDate = DateTime(value.year, value.month, value.day);
    return today.isBefore(allotmentDate);
  }

  AllotmentCheckResult _result({
    required Ipo ipo,
    required AllotmentApiStatus status,
    int? sharesAllotted,
    String? applicationNumber,
    String? message,
  }) {
    return AllotmentCheckResult(
      status: status,
      registrar: 'MUFG',
      ipoName: ipo.name,
      sharesAllotted: sharesAllotted,
      applicationNumber: applicationNumber,
      message: message,
    );
  }
}

class _MufgSession {
  _MufgSession()
      : _client = HttpClient()
          ..connectionTimeout = MufgAllotmentService._timeout
          ..autoUncompress = true;

  final HttpClient _client;
  final Map<String, Cookie> _cookies = <String, Cookie>{};

  Future<void> initialize() async {
    final request = await _client
        .getUrl(MufgAllotmentService._publicIssuesUri)
        .timeout(MufgAllotmentService._timeout);

    request.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml');
    request.headers.set(HttpHeaders.userAgentHeader, MufgAllotmentService._userAgent);
    request.headers.set('Accept-Language', 'en-US,en;q=0.9');

    for (final cookie in _cookies.values) {
      request.cookies.add(cookie);
    }

    final response = await request.close().timeout(MufgAllotmentService._timeout);
    _captureCookies(response);
    await response.drain();

    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw MufgAllotmentException(
        'MUFG session could not be started (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }


  Future<String> getDetailsWithBootstrap() async {
    try {
      // The ASMX endpoint may create its own ASP.NET session, so try the
      // shortest path first. This also avoids depending on the HTML page when
      // MUFG's edge protection allows the API call directly.
      return await postForDValue(MufgAllotmentService._getDetailsUri);
    } on MufgAllotmentException {
      // Browser traffic normally visits the public page first and receives
      // session/edge cookies. Reproduce that once, then retry GetDetails.
      await initialize();
      return postForDValue(MufgAllotmentService._getDetailsUri);
    }
  }

  Future<String> postForDValue(
    Uri uri, {
    Map<String, String>? payload,
  }) async {
    final request = await _client.postUrl(uri).timeout(MufgAllotmentService._timeout);

    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/javascript, */*; q=0.01',
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=UTF-8',
    );
    request.headers.set(HttpHeaders.userAgentHeader, MufgAllotmentService._userAgent);
    request.headers.set('Accept-Language', 'en-US,en;q=0.9');
    request.headers.set('Origin', MufgAllotmentService._origin);
    request.headers.set('Referer', MufgAllotmentService._referer);
    request.headers.set('X-Requested-With', 'XMLHttpRequest');

    for (final cookie in _cookies.values) {
      request.cookies.add(cookie);
    }

    if (payload == null) {
      request.contentLength = 0;
    } else {
      final encoded = utf8.encode(jsonEncode(payload));
      request.contentLength = encoded.length;
      request.add(encoded);
    }

    final response = await request.close().timeout(MufgAllotmentService._timeout);
    _captureCookies(response);
    final raw = await utf8.decoder.bind(response).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MufgAllotmentException(
        'MUFG request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const MufgAllotmentException(
        'MUFG returned a non-JSON response.',
      );
    }

    if (decoded is! Map) {
      throw const MufgAllotmentException(
        'MUFG returned an invalid response.',
      );
    }

    final d = decoded['d'];
    if (d == null) {
      throw const MufgAllotmentException(
        'MUFG response did not contain result data.',
      );
    }

    return d.toString();
  }

  void _captureCookies(HttpClientResponse response) {
    for (final cookie in response.cookies) {
      _cookies[cookie.name] = cookie;
    }
  }

  void close() {
    _client.close(force: true);
  }
}

class _MufgCompany {
  const _MufgCompany({required this.id, required this.name});

  final String id;
  final String name;
}

class MufgAllotmentException implements Exception {
  const MufgAllotmentException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
