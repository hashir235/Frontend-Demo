/// Fabrication's own optimizer setup.
///
/// Fabrication and estimation cut different stock for different jobs, so each
/// module keeps its own bar lengths, red zones and extra-pieces allowance.
/// Only the cutting margin is fabrication-only -- estimation carries a margin
/// per section instead of one for the whole module.
class FabricationSettingsModel {
  final double cuttingMarginCm;
  final Map<String, List<int>> sectionLengths;
  final int maxExtraPieces;
  final bool enforceMaxExtraPieces;
  final double redZoneEven;
  final double redZoneOdd;

  const FabricationSettingsModel({
    required this.cuttingMarginCm,
    this.sectionLengths = const <String, List<int>>{},
    this.maxExtraPieces = 1,
    this.enforceMaxExtraPieces = false,
    this.redZoneEven = 12.0,
    this.redZoneOdd = 13.0,
  });

  const FabricationSettingsModel.defaults()
    : cuttingMarginCm = 1.2,
      sectionLengths = const <String, List<int>>{},
      maxExtraPieces = 1,
      enforceMaxExtraPieces = false,
      redZoneEven = 12.0,
      redZoneOdd = 13.0;

  factory FabricationSettingsModel.fromJson(Map<String, dynamic> json) {
    final Object? rawValue = json['cuttingMarginCm'];
    double cuttingMarginCm = 1.2;
    if (rawValue is num) {
      cuttingMarginCm = rawValue.toDouble();
    } else if (rawValue is String) {
      cuttingMarginCm = double.tryParse(rawValue) ?? 1.2;
    }

    final Map<String, List<int>> parsedSectionLengths = <String, List<int>>{};
    final Object? rawSectionLengths = json['sectionLengths'];
    if (rawSectionLengths is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawSectionLengths.entries) {
        final Object? rawList = entry.value;
        if (rawList is List<dynamic>) {
          parsedSectionLengths[entry.key] = rawList
              .whereType<num>()
              .map((num value) => value.toInt())
              .toList(growable: false);
        }
      }
    }

    return FabricationSettingsModel(
      cuttingMarginCm: cuttingMarginCm,
      sectionLengths: parsedSectionLengths,
      maxExtraPieces: (json['maxExtraPieces'] as num?)?.toInt() ?? 1,
      enforceMaxExtraPieces: json['enforceMaxExtraPieces'] as bool? ?? false,
      redZoneEven:
          (json['redZoneEven'] as num?)?.toDouble() ??
          (json['redZone1'] as num?)?.toDouble() ??
          12.0,
      redZoneOdd:
          (json['redZoneOdd'] as num?)?.toDouble() ??
          (json['redZone2'] as num?)?.toDouble() ??
          13.0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'cuttingMarginCm': cuttingMarginCm,
      'sectionLengths': sectionLengths.map<String, Object?>(
        (String key, List<int> value) => MapEntry<String, Object?>(key, value),
      ),
      'maxExtraPieces': maxExtraPieces,
      'enforceMaxExtraPieces': enforceMaxExtraPieces,
      'redZoneEven': redZoneEven,
      'redZoneOdd': redZoneOdd,
    };
  }
}
