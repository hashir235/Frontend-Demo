class BillingSettingsModel {
  final String contractorName;
  final String workshopName;
  final String workshopPhone;
  final String workshopAddress;

  const BillingSettingsModel({
    required this.contractorName,
    required this.workshopName,
    required this.workshopPhone,
    required this.workshopAddress,
  });

  const BillingSettingsModel.empty()
    : contractorName = '',
      workshopName = '',
      workshopPhone = '',
      workshopAddress = '';

  factory BillingSettingsModel.fromJson(Map<String, dynamic> json) {
    return BillingSettingsModel(
      contractorName: json['contractorName'] as String? ?? '',
      workshopName: json['workshopName'] as String? ?? '',
      workshopPhone: json['workshopPhone'] as String? ?? '',
      workshopAddress: json['workshopAddress'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contractorName': contractorName,
      'workshopName': workshopName,
      'workshopPhone': workshopPhone,
      'workshopAddress': workshopAddress,
    };
  }
}
