import '../models/ipo.dart';

/// Temporary KFin IPO -> client_id registry.
///
/// KFin's PAN endpoint requires an IPO-specific `client_id`. Until we wire the
/// KFin IPO-list endpoint, keep only verified IDs here. Name matching is
/// normalized so Upstox/KFin differences like `IPO`, `LTD.` and `LIMITED`
/// don't break the lookup.
abstract class KfinClientIdRegistry {
  static const List<_KfinClientEntry> _entries = [
    _KfinClientEntry(
      ipoName: 'MILKY MIST DAIRY FOOD LIMITED',
      clientId: '29849673370',
    ),
    _KfinClientEntry(
      ipoName: 'CALIBER MINING AND LOGISTICS LIMITED',
      clientId: '89605487720',
    ),
  ];

  static String? resolve(Ipo ipo) {
    final requestedName = _normalize(ipo.name);
    if (requestedName.isEmpty) return null;

    for (final entry in _entries) {
      final candidate = _normalize(entry.ipoName);
      if (candidate == requestedName) {
        return entry.clientId;
      }
    }

    // Safe containment fallback for common suffix differences such as
    // `LIMITED IPO` vs no suffix in Upstox.
    for (final entry in _entries) {
      final candidate = _normalize(entry.ipoName);
      if (requestedName.contains(candidate) || candidate.contains(requestedName)) {
        return entry.clientId;
      }
    }

    return null;
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
}

class _KfinClientEntry {
  const _KfinClientEntry({
    required this.ipoName,
    required this.clientId,
  });

  final String ipoName;
  final String clientId;
}
