import '../../estimation/data/cost_table_api_client.dart';
import '../../estimation/data/optimization_repository.dart';
import '../../estimation/data/rate_review_api_client.dart';
import '../../estimation/models/cost_table.dart';
import '../../estimation/models/cutting_report.dart';
import '../../estimation/models/rate_review.dart';
import '../../estimation/models/window_review_item.dart';

String _trimFixed(double value, int decimals) {
  String text = value.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

String _formatFeetInches(double feet) {
  final double totalInches = feet * 12;
  int feetPart = totalInches ~/ 12;
  double inchPart = totalInches - (feetPart * 12);
  inchPart = (inchPart * 10).round() / 10;
  if (inchPart >= 12) {
    feetPart += 1;
    inchPart = 0;
  }
  return "$feetPart' ${_trimFixed(inchPart, 1)}\"";
}

class FabricationMockOptimizationRepository extends OptimizationRepository {
  @override
  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String displayUnit = 'ft',
    required String projectName,
    required String projectLocation,
  }) async {
    final List<CuttingReportCut> topCuts = <CuttingReportCut>[];
    final List<CuttingReportCut> bottomCuts = <CuttingReportCut>[];
    final List<String> symbols = <String>['WT', 'HL', 'HR', 'WB'];

    for (int i = 0; i < items.length; i++) {
      final WindowReviewItem item = items[i];
      final double length = 6.25 + (i % 4) * 0.75;
      final CuttingReportCut cut = CuttingReportCut(
        label:
            '${item.windowLabel} #${item.winNo} -> '
            '${item.heightValue}x${item.widthValue} | ${symbols[i % symbols.length]}',
        windowName: item.windowLabel,
        windowNo: item.winNo,
        dimension: '${item.heightValue}x${item.widthValue}',
        lengthFt: length,
        lengthDisplay: '${length.toStringAsFixed(2)} ft',
      );
      if (i.isEven) {
        topCuts.add(cut);
      } else {
        bottomCuts.add(cut);
      }
    }

    if (topCuts.isEmpty && items.isNotEmpty) {
      topCuts.add(
        CuttingReportCut(
          label:
              '${items.first.windowLabel} #${items.first.winNo} -> '
              '${items.first.heightValue}x${items.first.widthValue} | WT',
          windowName: items.first.windowLabel,
          windowNo: items.first.winNo,
          dimension: '${items.first.heightValue}x${items.first.widthValue}',
          lengthFt: 6.25,
          lengthDisplay: '6.25 ft',
        ),
      );
    }

    if (bottomCuts.isEmpty && items.isNotEmpty) {
      bottomCuts.add(
        CuttingReportCut(
          label:
              '${items.first.windowLabel} #${items.first.winNo} -> '
              '${items.first.heightValue}x${items.first.widthValue} | WB',
          windowName: items.first.windowLabel,
          windowNo: items.first.winNo,
          dimension: '${items.first.heightValue}x${items.first.widthValue}',
          lengthFt: 5.50,
          lengthDisplay: '5.50 ft',
        ),
      );
    }

    double totalLength(List<CuttingReportCut> cuts) {
      return cuts.fold<double>(0.0, (double sum, CuttingReportCut cut) {
        return sum + cut.lengthFt;
      });
    }

    CuttingReportSection makeSection(
      String name,
      List<CuttingReportCut> cuts,
      double stockLen,
    ) {
      final double total = totalLength(cuts);
      return CuttingReportSection(
        name: name,
        summary: CuttingReportSummary(
          usedLengths: <double>[stockLen],
          usedLengthsDisplay: <String>['${stockLen.toStringAsFixed(2)} ft'],
          totalLength: total,
          totalLengthDisplay: '${total.toStringAsFixed(2)} ft',
        ),
        allowedLengthsFt: <double>[stockLen],
        allowedLengthsDisplay: <String>['${stockLen.toStringAsFixed(2)} ft'],
        groups: <CuttingReportGroup>[
          CuttingReportGroup(
            stockLenFt: stockLen,
            stockLenDisplay: '${stockLen.toStringAsFixed(2)} ft',
            wastageFt: (stockLen - total).clamp(0, stockLen),
            wastageDisplay:
                '${(stockLen - total).clamp(0, stockLen).toStringAsFixed(2)} ft',
            offcut: false,
            cuts: cuts,
          ),
        ],
      );
    }

    return CuttingReport(
      ok: true,
      context: 'fabrication',
      displayUnit: displayUnit,
      errors: const <String>[],
      sections: <CuttingReportSection>[
        makeSection('Top', topCuts, 12.0),
        makeSection('Bottom', bottomCuts, 10.0),
      ],
    );
  }
}

class FabricationMockRateReviewApiClient extends RateReviewApiClient {
  @override
  Future<RateReview> fetchRateReview({
    required String gauge,
    required String color,
    String? projectId,
    String context = 'estimation',
  }) async {
    return RateReview(
      ok: true,
      errors: const <String>[],
      gauge: gauge,
      color: color,
      rows: <RateReviewRow>[
        RateReviewRow(
          section: 'WT',
          totalFt: 42.0,
          totalFtDisplay: _formatFeetInches(42.0),
          rate: 510.0,
        ),
        RateReviewRow(
          section: 'WB',
          totalFt: 38.5,
          totalFtDisplay: _formatFeetInches(38.5),
          rate: 500.0,
        ),
        RateReviewRow(
          section: 'HL',
          totalFt: 36.0,
          totalFtDisplay: _formatFeetInches(36.0),
          rate: 495.0,
        ),
        RateReviewRow(
          section: 'HR',
          totalFt: 36.0,
          totalFtDisplay: _formatFeetInches(36.0),
          rate: 495.0,
        ),
      ],
    );
  }
}

class FabricationMockCostTableApiClient extends CostTableApiClient {
  @override
  Future<CostTable> fetchCostTable({
    required String gauge,
    required String color,
    String? projectId,
    List<RateOverrideInput> overrides = const <RateOverrideInput>[],
    String context = 'estimation',
  }) async {
    final List<CostTableRow> baseRows = <CostTableRow>[
      CostTableRow(
        section: 'WT',
        totalFt: 42.0,
        totalFtDisplay: _formatFeetInches(42.0),
        rate: 510.0,
        totalPrice: 21420.0,
        lengths: <CostTableLength>[
          CostTableLength(
            lengthFt: 12.0,
            lengthDisplay: _formatFeetInches(12.0),
            quantity: 2,
          ),
          CostTableLength(
            lengthFt: 9.0,
            lengthDisplay: _formatFeetInches(9.0),
            quantity: 2,
          ),
        ],
      ),
      CostTableRow(
        section: 'WB',
        totalFt: 38.5,
        totalFtDisplay: _formatFeetInches(38.5),
        rate: 500.0,
        totalPrice: 19250.0,
        lengths: <CostTableLength>[
          CostTableLength(
            lengthFt: 10.0,
            lengthDisplay: _formatFeetInches(10.0),
            quantity: 2,
          ),
          CostTableLength(
            lengthFt: 9.25,
            lengthDisplay: _formatFeetInches(9.25),
            quantity: 2,
          ),
        ],
      ),
      CostTableRow(
        section: 'HL',
        totalFt: 36.0,
        totalFtDisplay: _formatFeetInches(36.0),
        rate: 495.0,
        totalPrice: 17820.0,
        lengths: <CostTableLength>[
          CostTableLength(
            lengthFt: 9.0,
            lengthDisplay: _formatFeetInches(9.0),
            quantity: 4,
          ),
        ],
      ),
      CostTableRow(
        section: 'HR',
        totalFt: 36.0,
        totalFtDisplay: _formatFeetInches(36.0),
        rate: 495.0,
        totalPrice: 17820.0,
        lengths: <CostTableLength>[
          CostTableLength(
            lengthFt: 9.0,
            lengthDisplay: _formatFeetInches(9.0),
            quantity: 4,
          ),
        ],
      ),
    ];

    final Map<String, double> overrideMap = <String, double>{};
    for (final RateOverrideInput item in overrides) {
      overrideMap[item.section] = item.rate;
    }

    final List<CostTableRow> rows = baseRows
        .map((CostTableRow row) {
          final double rate = overrideMap[row.section] ?? row.rate;
          return CostTableRow(
            section: row.section,
            totalFt: row.totalFt,
            totalFtDisplay: row.totalFtDisplay,
            rate: rate,
            totalPrice: row.totalFt * rate,
            lengths: row.lengths,
          );
        })
        .toList(growable: false);

    final double grandTotal = rows.fold<double>(0.0, (
      double sum,
      CostTableRow row,
    ) {
      return sum + row.totalPrice;
    });

    return CostTable(
      ok: true,
      errors: const <String>[],
      context: 'fabrication',
      gauge: gauge,
      color: color,
      grandTotal: grandTotal,
      rows: rows,
    );
  }
}
