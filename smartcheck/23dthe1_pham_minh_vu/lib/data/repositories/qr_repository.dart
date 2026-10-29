import '../../core/api_client.dart';
import '../models/qr_code.dart';

class QrRepository {
  QrRepository(this._api);
  final ApiClient _api;

  Future<QrCodeInfo> current(int locationId) async => QrCodeInfo.fromJson(
      ((await _api.get('/api/qr/current', query: {'locationId': locationId})) as Map).cast());
}
