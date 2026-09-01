enum IpoType { mainboard, sme }

enum IpoStatus { open, upcoming, closed, listed }

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
    this.isDetailed = false,
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
  final bool isDetailed;

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

  Ipo mergeDetailsFrom(Ipo details) {
    return Ipo(
      id: id,
      name: name,
      symbol: symbol,
      type: type,
      status: status,
      issueType: issueType,
      minPrice: details.minPrice ?? minPrice,
      maxPrice: details.maxPrice ?? maxPrice,
      lotSize: details.lotSize ?? lotSize,
      openDate: details.openDate ?? openDate,
      closeDate: details.closeDate ?? closeDate,
      allotmentDate: details.allotmentDate ?? allotmentDate,
      listingDate: details.listingDate ?? listingDate,
      registrarName: details.registrarName ?? registrarName,
      registrarCode: details.registrarCode ?? registrarCode,
      issueSizeCrore: details.issueSizeCrore ?? issueSizeCrore,
      industry: details.industry ?? industry,
      totalSubscription: details.totalSubscription ?? totalSubscription,
      listingPrice: details.listingPrice ?? listingPrice,
      listingExchange: details.listingExchange ?? listingExchange,
      cutOffPrice: details.cutOffPrice ?? cutOffPrice,
      isDetailed: isDetailed || details.isDetailed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'type': type.name,
    'status': status.name,
    'issueType': issueType,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'lotSize': lotSize,
    'openDate': openDate?.toIso8601String(),
    'closeDate': closeDate?.toIso8601String(),
    'allotmentDate': allotmentDate?.toIso8601String(),
    'listingDate': listingDate?.toIso8601String(),
    'registrarName': registrarName,
    'registrarCode': registrarCode,
    'issueSizeCrore': issueSizeCrore,
    'industry': industry,
    'totalSubscription': totalSubscription,
    'listingPrice': listingPrice,
    'listingExchange': listingExchange,
    'cutOffPrice': cutOffPrice,
    'isDetailed': isDetailed,
  };

  factory Ipo.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) {
      final value = raw?.toString();
      return values.firstWhere(
        (item) => item.name == value,
        orElse: () => fallback,
      );
    }

    DateTime? date(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    double? number(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    int? integer(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '');
    }

    return Ipo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown IPO',
      symbol: json['symbol']?.toString() ?? '',
      type: enumValue(IpoType.values, json['type'], IpoType.mainboard),
      status: enumValue(IpoStatus.values, json['status'], IpoStatus.open),
      issueType: json['issueType']?.toString() ?? 'IPO',
      minPrice: number(json['minPrice']),
      maxPrice: number(json['maxPrice']),
      lotSize: integer(json['lotSize']),
      openDate: date(json['openDate']),
      closeDate: date(json['closeDate']),
      allotmentDate: date(json['allotmentDate']),
      listingDate: date(json['listingDate']),
      registrarName: json['registrarName']?.toString(),
      registrarCode: json['registrarCode']?.toString(),
      issueSizeCrore: number(json['issueSizeCrore']),
      industry: json['industry']?.toString(),
      totalSubscription: number(json['totalSubscription']),
      listingPrice: number(json['listingPrice']),
      listingExchange: json['listingExchange']?.toString(),
      cutOffPrice: number(json['cutOffPrice']),
      isDetailed: json['isDetailed'] == true,
    );
  }
}
