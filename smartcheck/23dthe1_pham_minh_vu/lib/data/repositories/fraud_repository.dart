import '../../core/api_client.dart';
import '../models/fraud_alert.dart';

class FraudRepository {
  FraudRepository(this._api);
  final ApiClient _api;

  /// `resolved`: `null` = tất cả. Server trả tối đa 200 dòng mới nhất.
  Future<List<FraudAlert>> list({bool? resolved}) async {
    final data = await _api.get('/api/fraud-alerts', query: {'resolved': ?resolved});
    return (data as List).map((e) => FraudAlert.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> resolve(int id) async {
    await _api.post('/api/fraud-alerts/$id/resolve');
  }
}
