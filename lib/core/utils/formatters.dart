import '../../data/models/ipo.dart';

abstract class Formatters {
  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String shortDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day} ${_months[date.month - 1]}';
  }

  static String fullDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static String money(num? value, {int decimals = 0}) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(decimals)}';
  }

  static String priceBand(Ipo ipo) {
    if (ipo.minPrice == null && ipo.maxPrice == null) return '—';
    if (ipo.minPrice == ipo.maxPrice) return money(ipo.maxPrice);
    return '${money(ipo.minPrice)} – ${money(ipo.maxPrice)}';
  }

  static String compactNumber(num? value) {
    if (value == null) return '—';
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  static String maskPan(String pan) {
    final normalized = pan.toUpperCase().trim();
    if (normalized.length <= 5) return normalized;
    return '${'*' * (normalized.length - 5)}${normalized.substring(normalized.length - 5)}';
  }

  static String initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'IPO';
    if (words.length == 1) {
      final word = words.first;
      return (word.length <= 2 ? word : word.substring(0, 2)).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = dateOnly(DateTime.now());
    return dateOnly(date) == now;
  }

  static String relativeDay(DateTime? date, {bool capitalize = true}) {
    if (date == null) return 'Date pending';
    final today = dateOnly(DateTime.now());
    final target = dateOnly(date);
    final days = target.difference(today).inDays;

    final text = switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      -1 => 'yesterday',
      > 1 => 'in $days days',
      _ => '${days.abs()} days ago',
    };

    if (!capitalize || text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static String eventRelative(String event, DateTime? date) {
    if (date == null) return '$event date pending';
    return '$event ${relativeDay(date, capitalize: false)}';
  }

  static String lastUpdated(DateTime? date) {
    if (date == null) return 'Not refreshed yet';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 45) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${shortDate(date)}';
  }
}
