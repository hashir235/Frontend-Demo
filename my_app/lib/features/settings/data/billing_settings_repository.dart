import '../models/billing_settings.dart';
import 'billing_settings_api_client.dart';

class BillingSettingsRepository {
  final BillingSettingsApiClient _apiClient;

  BillingSettingsRepository({
    BillingSettingsApiClient? apiClient,
  }) : _apiClient = apiClient ?? BillingSettingsApiClient();

  Future<BillingSettingsModel> fetchBillingSettings() {
    return _apiClient.fetchBillingSettings();
  }

  Future<BillingSettingsModel> saveBillingSettings(
    BillingSettingsModel settings,
  ) {
    return _apiClient.saveBillingSettings(settings);
  }
}
