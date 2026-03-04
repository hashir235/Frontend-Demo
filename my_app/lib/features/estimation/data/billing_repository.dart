import '../models/bill_request.dart';
import '../models/bill_snapshot.dart';
import 'billing_api_client.dart';

class BillingRepository {
  final BillingApiClient _apiClient;

  BillingRepository({
    BillingApiClient? apiClient,
  }) : _apiClient = apiClient ?? BillingApiClient();

  Future<BillSnapshot> estimateBill(BillRequest request) {
    return _apiClient.estimateBill(request);
  }
}
