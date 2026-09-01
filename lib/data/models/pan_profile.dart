class PanProfile {
  const PanProfile({
    required this.id,
    required this.name,
    required this.maskedPan,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String maskedPan;
  final bool isDefault;

  PanProfile copyWith({
    String? id,
    String? name,
    String? maskedPan,
    bool? isDefault,
  }) {
    return PanProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      maskedPan: maskedPan ?? this.maskedPan,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maskedPan': maskedPan,
        'isDefault': isDefault,
      };

  factory PanProfile.fromJson(Map<String, dynamic> json) => PanProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        maskedPan: json['maskedPan'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
