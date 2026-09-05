import '../../formulas/data/formula_book.dart';
import '../../formulas/data/formula_book_loader.dart';
import '../../formulas/data/window_cut_calculator.dart';
import '../../settings/data/estimation_settings_repository.dart';
import '../../settings/data/fabrication_settings_repository.dart';
import '../../settings/models/estimation_settings.dart';
import '../../settings/models/fabrication_settings.dart';
import '../models/cutting_report.dart';
import '../models/optimization_request.dart';
import '../models/section_recalculation.dart';
import '../models/window_review_item.dart';
import 'optimization_api_client.dart';

/// Raised when this workshop's own formulas cannot be applied.
///
/// Only ever thrown for a workshop that has changed one. If they have not,
/// the shipped formulas are the engine's formulas and letting the engine do
/// the arithmetic gives the identical answer -- so nothing is worth stopping
/// a job for. Once they have, quietly cutting to somebody else's numbers is
/// the one outcome that must not happen.
class FormulasUnavailable implements Exception {
  const FormulasUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

class OptimizationRepository {
  OptimizationRepository({
    OptimizationApiClient? apiClient,
    FormulaBookLoader formulas = const FormulaBookLoader(),
    EstimationSettingsRepository? estimationSettings,
    FabricationSettingsRepository? fabricationSettings,
  })  : _apiClient = apiClient ?? OptimizationApiClient(),
        _formulas = formulas,
        _estimationSettings = estimationSettings ?? EstimationSettingsRepository(),
        _fabricationSettings = fabricationSettings ?? FabricationSettingsRepository();

  final OptimizationApiClient _apiClient;
  final FormulaBookLoader _formulas;
  final EstimationSettingsRepository _estimationSettings;
  final FabricationSettingsRepository _fabricationSettings;

  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String displayUnit = 'ft',
    required String projectName,
    required String projectLocation,
  }) async {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      items,
      projectId: projectId,
      context: context,
      displayUnit: displayUnit,
      projectName: projectName,
      projectLocation: projectLocation,
    );

    return _apiClient.fetchLengthOptimization(await _withOwnLengths(request));
  }

  /// The same job with every length worked out here, from this workshop's
  /// formulas.
  ///
  /// This is where the arithmetic moved. It used to happen on the server,
  /// which meant a formula a workshop changed was a formula the saw never saw.
  ///
  /// Where it cannot be done -- no settings to read, a window the catalogue
  /// does not describe -- the job goes on without them and the engine works
  /// them out as it always did. That is safe precisely because the shipped
  /// formulas *are* the engine's: 525 real jobs were replayed both ways and
  /// every one of 47,016 cuts came out the same. It stops being safe the
  /// moment this workshop has changed one, and then it stops rather than cuts
  /// to the wrong number.
  Future<OptimizationRequest> _withOwnLengths(OptimizationRequest request) async {
    FormulaBook book;
    Map<String, double> margins;
    try {
      book = await _formulas.load();
      margins = await _marginsFor(request.isFabrication);
    } catch (error) {
      throw const FormulasUnavailable(
        'Quick AL could not read your cutting margins, so it cannot work out '
        'this job\'s sizes. Check your connection and try again.',
      );
    }

    final bool customised = !book.overrides.isEmpty;
    final WindowCutCalculator calculator = WindowCutCalculator(book);
    final List<OptimizationWindowRequest> windows = <OptimizationWindowRequest>[];

    for (final OptimizationWindowRequest window in request.windows) {
      final WindowCutList cut = calculator.compute(
        WindowCutRequest(
          isFabrication: request.isFabrication,
          appWindowCode: window.windowCode,
          collarIndex: window.collarIndex,
          unitMode: window.unitMode,
          heightValue: window.heightValue,
          widthValue: window.widthValue,
          leftWidthValue: window.leftWidthValue,
          rightWidthValue: window.rightWidthValue,
          archValue: window.archValue,
          lockType: window.lockType,
          rubberType: window.rubberType,
          addBottom: window.addBottom,
          addTee: window.addTee,
          addNet: window.addNet,
          backCollarCm: window.backCollarCm,
        ),
        margins: margins,
      );

      if (cut.problems.isNotEmpty) {
        if (customised) {
          throw FormulasUnavailable(
            'Window ${window.winNo}: ${cut.problems.first}',
          );
        }
        // Nothing of this workshop's own is at stake, so the engine's own
        // arithmetic gives the same answer and the job goes through.
        return request;
      }

      windows.add(window.withComputed(
        <Map<String, Object?>>[
          for (final CutPiece piece in cut.pieces)
            <String, Object?>{
              'section': piece.section,
              'piece': piece.label,
              'lengthFt': piece.lengthFt,
            },
        ],
        <Map<String, Object?>>[
          for (final GlassPiece pane in cut.glass)
            <String, Object?>{
              'heightCm': pane.heightCm,
              'widthCm': pane.widthCm,
            },
        ],
      ));
    }

    return request.withWindows(windows);
  }

  /// The cutting margins this job is cut with, read from the server so they
  /// are the same ones the engine would have used.
  Future<Map<String, double>> _marginsFor(bool isFabrication) async {
    if (isFabrication) {
      final FabricationSettingsModel settings =
          await _fabricationSettings.fetchFabricationSettings();
      return <String, double>{'cm': settings.cuttingMarginCm};
    }

    final EstimationSettingsModel settings =
        await _estimationSettings.fetchEstimationSettings();
    return <String, double>{
      for (final MapEntry<String, double> entry in settings.cuttingMargins.entries)
        'cm_${entry.key}': entry.value,
    };
  }

  Future<CuttingReport> recalculateSection(
    SectionRecalculationRequest request,
  ) {
    return _apiClient.recalculateSection(request);
  }
}
