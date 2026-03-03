import '../models/cutting_report.dart';
import '../models/optimization_request.dart';
import '../models/window_review_item.dart';
import 'optimization_api_client.dart';

class OptimizationRepository {
  final OptimizationApiClient _apiClient;

  OptimizationRepository({OptimizationApiClient? apiClient})
    : _apiClient = apiClient ?? OptimizationApiClient();

  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String context = 'estimation',
    String displayUnit = 'ft',
  }) {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      items,
      context: context,
      displayUnit: displayUnit,
    );
    return _apiClient.fetchLengthOptimization(request);
  }
}
