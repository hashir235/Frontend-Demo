class BillingSettingsModel {
  final String contractorName;
  final String workshopName;
  final String workshopPhone;
  final String workshopAddress;

  /// Which city's rates this workshop works to.
  ///
  /// Blank on a workshop set up before the field existed. Blank is left alone
  /// rather than guessed at: putting someone on the wrong city's rates without
  /// telling them would be worse than having no city at all, so callers treat
  /// an empty value as "not chosen yet" and ask.
  final String city;

  const BillingSettingsModel({
    required this.contractorName,
    required this.workshopName,
    required this.workshopPhone,
    required this.workshopAddress,
    this.city = '',
  });

  const BillingSettingsModel.empty()
    : contractorName = '',
      workshopName = '',
      workshopPhone = '',
      workshopAddress = '',
      city = '';

  BillingSettingsModel copyWith({
    String? contractorName,
    String? workshopName,
    String? workshopPhone,
    String? workshopAddress,
    String? city,
  }) {
    return BillingSettingsModel(
      contractorName: contractorName ?? this.contractorName,
      workshopName: workshopName ?? this.workshopName,
      workshopPhone: workshopPhone ?? this.workshopPhone,
      workshopAddress: workshopAddress ?? this.workshopAddress,
      city: city ?? this.city,
    );
  }

  factory BillingSettingsModel.fromJson(Map<String, dynamic> json) {
    return BillingSettingsModel(
      contractorName: json['contractorName'] as String? ?? '',
      workshopName: json['workshopName'] as String? ?? '',
      workshopPhone: json['workshopPhone'] as String? ?? '',
      workshopAddress: json['workshopAddress'] as String? ?? '',
      city: (json['city'] as String? ?? '').trim(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contractorName': contractorName,
      'workshopName': workshopName,
      'workshopPhone': workshopPhone,
      'workshopAddress': workshopAddress,
      'city': city,
    };
  }
}
