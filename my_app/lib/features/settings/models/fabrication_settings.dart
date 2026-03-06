class FabricationSettingsModel {
  final double cuttingMarginCm;

  const FabricationSettingsModel({required this.cuttingMarginCm});

  const FabricationSettingsModel.defaults() : cuttingMarginCm = 1.2;

  factory FabricationSettingsModel.fromJson(Map<String, dynamic> json) {
    final Object? rawValue = json['cuttingMarginCm'];
    double cuttingMarginCm = 1.2;
    if (rawValue is num) {
      cuttingMarginCm = rawValue.toDouble();
    } else if (rawValue is String) {
      cuttingMarginCm = double.tryParse(rawValue) ?? 1.2;
    }
    return FabricationSettingsModel(cuttingMarginCm: cuttingMarginCm);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'cuttingMarginCm': cuttingMarginCm};
  }
}
