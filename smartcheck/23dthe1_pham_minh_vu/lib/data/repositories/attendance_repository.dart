import '../../core/api_client.dart';
import '../models/attendance.dart';
import '../models/attendance_record.dart';
import '../models/attendance_report.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);
  final ApiClient _api;

  Future<CheckResult> check(AttendanceType type, CheckPayload payload) async => CheckResult.fromJson(
      ((await _api.post('/api/attendance/${type.path}', body: payload.toJson())) as Map).cast());

  /// Admin/Manager: chấm công của mọi nhân viên (hoặc một người) trong khoảng [from, to].
  /// Server giới hạn 200 dòng/trang, mới nhất trước.
  Future<AttendanceList> list({DateTime? from, DateTime? to, String? userId, int page = 1, int pageSize = 200}) async {
    final data = (await _api.get('/api/attendance', query: {
      'page': page,
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

  /// Lịch sử chấm công của chính mình trong [days] ngày gần nhất (server giới hạn 1..365), mới nhất trước.
  Future<List<MyAttendance>> mine({int days = 30}) async {
    final data = await _api.get('/api/attendance/my', query: {'days': days});
    return (data as List).map((e) => MyAttendance.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Bảng công tháng. Nhân viên chỉ nhận dòng của mình; Admin/Manager nhận tất cả (hoặc lọc theo [userId]).
  Future<MonthlyReport> report({required int year, required int month, String? userId}) async => MonthlyReport.fromJson(
      ((await _api.get('/api/attendance/report', query: {'year': year, 'month': month, 'userId': ?userId})) as Map).cast());
}
