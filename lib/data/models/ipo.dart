enum IpoType { mainboard, sme }

enum IpoStatus { open, closed, listed, upcoming }

class Ipo {
  const Ipo({
    required this.id,
    required this.name,
    required this.symbol,
    required this.type,
    required this.status,
    required this.issueType,
    required this.minPrice,
    required this.maxPrice,
    required this.lotSize,
    required this.openDate,
    required this.closeDate,
    required this.allotmentDate,
    required this.listingDate,
    required this.registrarName,
    required this.registrarCode,
    this.issueSizeCrore,
    this.industry,
    this.totalSubscription,
    this.listingPrice,
    this.listingExchange,
    this.cutOffPrice,
  });

  final String id;
  final String name;
  final String symbol;
  final IpoType type;
  final IpoStatus status;
  final String issueType;
  final double? minPrice;
  final double? maxPrice;
  final int? lotSize;
  final DateTime? openDate;
  final DateTime? closeDate;
  final DateTime? allotmentDate;
  final DateTime? listingDate;
  final String? registrarName;
  final String? registrarCode;
  final double? issueSizeCrore;
  final String? industry;
  final double? totalSubscription;
  final double? listingPrice;
  final String? listingExchange;
  final double? cutOffPrice;

  double? get minimumInvestment {
    if (maxPrice == null || lotSize == null) return null;
    return maxPrice! * lotSize!;
  }

  double? get listingGainPercent {
    final base = cutOffPrice ?? maxPrice;
    if (listingPrice == null || base == null || base <= 0) return null;
    return ((listingPrice! - base) / base) * 100;
  }

  String get typeLabel => type == IpoType.mainboard ? 'MAINBOARD' : 'SME';

  String get statusLabel => switch (status) {
    IpoStatus.open => 'OPEN',
    IpoStatus.upcoming => 'UPCOMING',
    IpoStatus.closed => 'CLOSED',
    IpoStatus.listed => 'LISTED',
  };
}
