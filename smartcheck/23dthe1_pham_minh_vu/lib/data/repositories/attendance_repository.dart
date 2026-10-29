import '../../core/api_client.dart';
import '../models/attendance.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);
  final ApiClient _api;

  Future<CheckResult> check(AttendanceType type, CheckPayload payload) async => CheckResult.fromJson(
      ((await _api.post('/api/attendance/${type.path}', body: payload.toJson())) as Map).cast());

  /// Admin/Manager: chấm công của mọi nhân viên (hoặc một người) trong khoảng [from, to].
  /// Server giới hạn 200 dòng/trang, mới nhất trước.
  Future<AttendanceList> list({DateTime? from, DateTime? to, String? userId, int pageSize = 200}) async {
    final data = (await _api.get('/api/attendance', query: {
      'pageSize': pageSize,
      'from': ?from?.toUtc().toIso8601String(),
      'to': ?to?.toUtc().toIso8601String(),
      'userId': ?userId,
    })) as Map;
    return AttendanceList(
      total: (data['total'] as num).toInt(),
      items: (data['items'] as List).map((e) => AttendanceRecord.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}
