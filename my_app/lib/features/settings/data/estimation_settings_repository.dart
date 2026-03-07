import '../models/estimation_settings.dart';
import 'estimation_settings_api_client.dart';

class EstimationSettingsRepository {
  final EstimationSettingsApiClient _apiClient;

  EstimationSettingsRepository({EstimationSettingsApiClient? apiClient})
    : _apiClient = apiClient ?? EstimationSettingsApiClient();

  Future<EstimationSettingsModel> fetchEstimationSettings() {
    return _apiClient.fetchEstimationSettings();
  }

  Future<EstimationSettingsModel> saveEstimationSettings(
    EstimationSettingsModel settings,
  ) {
    return _apiClient.saveEstimationSettings(settings);
  }
}
