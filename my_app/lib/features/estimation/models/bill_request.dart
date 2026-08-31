class BillRequest {
  final String? projectId;
  final double glassRatePerSqFt;
  final double laborRatePerSqFt;
  final double hardwareRatePerWindow;

  /// Hardware rate per window type, keyed by the window name the bill groups
  /// by. Empty when the job holds only one type, or for anything the engine
  /// should price at [hardwareRatePerWindow] instead.
  final Map<String, double> hardwareRateByType;

  final double aluminiumDiscountPercent;
  final double aluminiumTotal;
  final double extraCharges;
  final double advancePaid;
  final String gauge;
  final String aluminiumColor;
  final String glassColor;
  final String aluminiumCompany;
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
    this.hardwareRateByType = const <String, double>{},
    required this.aluminiumDiscountPercent,
    required this.aluminiumTotal,
    required this.extraCharges,
    required this.advancePaid,
    required this.gauge,
    required this.aluminiumColor,
    required this.glassColor,
    this.aluminiumCompany = '',
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
      // Left out entirely when empty rather than sent as {}, so an unchanged
      // single-rate bill goes over the wire exactly as it always did.
      if (hardwareRateByType.isNotEmpty)
        'hardwareRateByType': hardwareRateByType,
      'aluminiumDiscountPercent': aluminiumDiscountPercent,
      'aluminiumTotal': aluminiumTotal,
      'extraCharges': extraCharges,
      'advancePaid': advancePaid,
      'gauge': gauge,
      'aluminiumColor': aluminiumColor,
      'glassColor': glassColor,
      'aluminiumCompany': aluminiumCompany,
      'projectName': projectName,
      'projectLocation': projectLocation,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
    };
  }
}
