import 'cutting_report.dart';

class SectionStockAvailability {
  final double lengthFt;
  final int? quantity;

  const SectionStockAvailability({
    required this.lengthFt,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lengthFt': lengthFt,
      if (quantity != null) 'quantity': quantity,
    };
  }
}

class SectionRecalculationRequest {
  final String? projectId;
  final String context;
  final String displayUnit;
  final String sectionName;

  /// Which pile of [sectionName]: a job can hold M23 in two gauges or two
  /// colours, and only this one may be replaced. Empty on a report made
  /// before per-window stock.
  final String sectionGauge;
  final String sectionColor;

  final List<CuttingReportCut> sourceCuts;
  final List<SectionStockAvailability> stockOptions;

  const SectionRecalculationRequest({
    this.projectId,
    required this.context,
    required this.displayUnit,
    required this.sectionName,
    this.sectionGauge = '',
    this.sectionColor = '',
    required this.sourceCuts,
    required this.stockOptions,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (projectId != null && projectId!.isNotEmpty) 'projectId': projectId,
      'context': context,
      'displayUnit': displayUnit,
      'sectionName': sectionName,
      'sectionGauge': sectionGauge,
      'sectionColor': sectionColor,
      'sourceCuts': sourceCuts
          .map((CuttingReportCut cut) => cut.toJson())
          .toList(growable: false),
      'stockOptions': stockOptions
          .map((SectionStockAvailability option) => option.toJson())
          .toList(growable: false),
    };
  }
}
