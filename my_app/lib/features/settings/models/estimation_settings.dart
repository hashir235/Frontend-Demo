class EstimationSettingsModel {
  final Map<String, List<int>> sectionLengths;
  final Map<String, double> cuttingMargins;
  final int maxExtraPieces;
  final bool enforceMaxExtraPieces;
  final double redZoneEven;
  final double redZoneOdd;

  const EstimationSettingsModel({
    required this.sectionLengths,
    required this.cuttingMargins,
    required this.maxExtraPieces,
    required this.enforceMaxExtraPieces,
    required this.redZoneEven,
    required this.redZoneOdd,
  });

  const EstimationSettingsModel.empty()
    : sectionLengths = const <String, List<int>>{},
      cuttingMargins = const <String, double>{},
      maxExtraPieces = 1,
      enforceMaxExtraPieces = false,
      redZoneEven = 12.0,
      redZoneOdd = 13.0;

  factory EstimationSettingsModel.fromJson(Map<String, dynamic> json) {
    final Map<String, List<int>> parsedSectionLengths = <String, List<int>>{};
    final Map<String, double> parsedCuttingMargins = <String, double>{};

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

    final Object? rawCuttingMargins = json['cuttingMargins'];
    if (rawCuttingMargins is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawCuttingMargins.entries) {
        final Object? rawValue = entry.value;
        if (rawValue is num) {
          parsedCuttingMargins[entry.key] = rawValue.toDouble();
        }
      }
    }

    return EstimationSettingsModel(
      sectionLengths: parsedSectionLengths,
      cuttingMargins: parsedCuttingMargins,
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
      'sectionLengths': sectionLengths.map<String, Object?>(
        (String key, List<int> value) => MapEntry<String, Object?>(key, value),
      ),
      'cuttingMargins': cuttingMargins.map<String, Object?>(
        (String key, double value) => MapEntry<String, Object?>(key, value),
      ),
      'maxExtraPieces': maxExtraPieces,
      'enforceMaxExtraPieces': enforceMaxExtraPieces,
      'redZoneEven': redZoneEven,
      'redZoneOdd': redZoneOdd,
    };
  }
}
