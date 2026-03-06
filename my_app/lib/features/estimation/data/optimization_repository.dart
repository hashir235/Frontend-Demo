import '../models/cutting_report.dart';
import '../models/optimization_request.dart';
import '../models/section_recalculation.dart';
import '../models/window_review_item.dart';
import 'optimization_api_client.dart';

class OptimizationRepository {
  final OptimizationApiClient _apiClient;

  OptimizationRepository({OptimizationApiClient? apiClient})
    : _apiClient = apiClient ?? OptimizationApiClient();

  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String displayUnit = 'ft',
    required String projectName,
    required String projectLocation,
  }) {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      items,
      projectId: projectId,
      context: context,
      displayUnit: displayUnit,
      projectName: projectName,
      projectLocation: projectLocation,
    );
    return _apiClient.fetchLengthOptimization(request);
  }

  Future<CuttingReport> recalculateSection(
    SectionRecalculationRequest request,
  ) {
    return _apiClient.recalculateSection(request);
  }
}
