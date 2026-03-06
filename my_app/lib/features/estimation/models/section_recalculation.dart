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
  final List<CuttingReportCut> sourceCuts;
  final List<SectionStockAvailability> stockOptions;

  const SectionRecalculationRequest({
    this.projectId,
    required this.context,
    required this.displayUnit,
    required this.sectionName,
    required this.sourceCuts,
    required this.stockOptions,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (projectId != null && projectId!.isNotEmpty) 'projectId': projectId,
      'context': context,
      'displayUnit': displayUnit,
      'sectionName': sectionName,
      'sourceCuts': sourceCuts
          .map((CuttingReportCut cut) => cut.toJson())
          .toList(growable: false),
      'stockOptions': stockOptions
          .map((SectionStockAvailability option) => option.toJson())
          .toList(growable: false),
    };
  }
}
