import '../models/fabrication_settings.dart';
import 'fabrication_settings_api_client.dart';

class FabricationSettingsRepository {
  final FabricationSettingsApiClient _apiClient;

  FabricationSettingsRepository({FabricationSettingsApiClient? apiClient})
    : _apiClient = apiClient ?? FabricationSettingsApiClient();

  Future<FabricationSettingsModel> fetchFabricationSettings() {
    return _apiClient.fetchFabricationSettings();
  }

  Future<FabricationSettingsModel> saveFabricationSettings(
    FabricationSettingsModel settings,
  ) {
    return _apiClient.saveFabricationSettings(settings);
  }
}
