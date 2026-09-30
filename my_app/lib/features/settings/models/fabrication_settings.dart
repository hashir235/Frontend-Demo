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

  /// Cut M23 and M28 two bars at a time: every bar of theirs gets a twin with
  /// exactly the same cuts, so two lengths can be clamped and sawn together.
  /// Off unless the workshop turns it on.
  final bool pairCutting;

  /// The same for D29 -- two equal heights and two equal widths per window.
  /// Its own switch: a workshop may clamp one pair of profiles and not the
  /// other.
  final bool pairCuttingD29;

  /// Cut M24 four bars at a time: a window's own M24 of one length in fours,
  /// what is left in twos. With it on, a window measured side by side whose
  /// top and bottom differ by half an inch or more has its top rails cut to
  /// the top and its bottom rails to the bottom. Off unless the workshop turns
  /// it on.
  final bool quadCuttingM24;

  const FabricationSettingsModel({
    required this.cuttingMarginCm,
    this.sectionLengths = const <String, List<int>>{},
    this.maxExtraPieces = 1,
    this.enforceMaxExtraPieces = false,
    this.redZoneEven = 12.0,
    this.redZoneOdd = 13.0,
    this.pairCutting = false,
    this.pairCuttingD29 = false,
    this.quadCuttingM24 = false,
  });

  const FabricationSettingsModel.defaults()
    : cuttingMarginCm = 1.2,
      sectionLengths = const <String, List<int>>{},
      maxExtraPieces = 1,
      enforceMaxExtraPieces = false,
      redZoneEven = 12.0,
      redZoneOdd = 13.0,
      pairCutting = false,
      pairCuttingD29 = false,
      quadCuttingM24 = false;

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
      // Absent from a server that predates pair cutting: off.
      pairCutting: json['pairCutting'] == true,
      pairCuttingD29: json['pairCuttingD29'] == true,
      quadCuttingM24: json['quadCuttingM24'] == true,
    );
  }

  /// These settings with the pair-cutting switches changed.
  FabricationSettingsModel copyWithPairCutting({
    required bool pairCutting,
    required bool pairCuttingD29,
    required bool quadCuttingM24,
  }) {
    return FabricationSettingsModel(
      cuttingMarginCm: cuttingMarginCm,
      sectionLengths: sectionLengths,
      maxExtraPieces: maxExtraPieces,
      enforceMaxExtraPieces: enforceMaxExtraPieces,
      redZoneEven: redZoneEven,
      redZoneOdd: redZoneOdd,
      pairCutting: pairCutting,
      pairCuttingD29: pairCuttingD29,
      quadCuttingM24: quadCuttingM24,
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
      'pairCutting': pairCutting,
      'pairCuttingD29': pairCuttingD29,
      'quadCuttingM24': quadCuttingM24,
    };
  }
}
