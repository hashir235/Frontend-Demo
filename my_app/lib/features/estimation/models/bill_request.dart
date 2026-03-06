class BillRequest {
  final String? projectId;
  final double glassRatePerSqFt;
  final double laborRatePerSqFt;
  final double hardwareRatePerWindow;
  final double aluminiumDiscountPercent;
  final double aluminiumTotal;
  final double extraCharges;
  final double advancePaid;
  final String gauge;
  final String aluminiumColor;
  final String glassColor;
  final String projectName;
  final String projectLocation;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const BillRequest({
    required this.projectId,
    required this.glassRatePerSqFt,
    required this.laborRatePerSqFt,
    required this.hardwareRatePerWindow,
    required this.aluminiumDiscountPercent,
    required this.aluminiumTotal,
    required this.extraCharges,
    required this.advancePaid,
    required this.gauge,
    required this.aluminiumColor,
    required this.glassColor,
    required this.projectName,
    required this.projectLocation,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'projectId': projectId,
      'glassRatePerSqFt': glassRatePerSqFt,
      'laborRatePerSqFt': laborRatePerSqFt,
      'hardwareRatePerWindow': hardwareRatePerWindow,
      'aluminiumDiscountPercent': aluminiumDiscountPercent,
      'aluminiumTotal': aluminiumTotal,
      'extraCharges': extraCharges,
      'advancePaid': advancePaid,
      'gauge': gauge,
      'aluminiumColor': aluminiumColor,
      'glassColor': glassColor,
      'projectName': projectName,
      'projectLocation': projectLocation,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
    };
  }
}
