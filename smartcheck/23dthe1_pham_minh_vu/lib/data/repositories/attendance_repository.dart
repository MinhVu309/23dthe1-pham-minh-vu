import '../../core/api_client.dart';
import '../models/attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);
  final ApiClient _api;

  Future<CheckResult> check(AttendanceType type, CheckPayload payload) async => CheckResult.fromJson(
      ((await _api.post('/api/attendance/${type.path}', body: payload.toJson())) as Map).cast());
}
