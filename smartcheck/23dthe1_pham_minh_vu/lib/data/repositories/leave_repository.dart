import '../../core/api_client.dart';
import '../models/leave.dart';

class LeaveRepository {
  LeaveRepository(this._api);
  final ApiClient _api;

  /// Nhân viên chỉ thấy đơn của mình; Admin/Manager thấy tất cả. Trả về mảng (không phân trang).
  Future<List<Leave>> list({LeaveStatus? status}) async {
    final data = await _api.get('/api/leaves', query: {if (status != null) 'status': status.apiName});
    return (data as List).map((e) => Leave.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> create({required DateTime from, required DateTime to, required String reason}) async {
    await _api.post('/api/leaves', body: {'fromDate': Leave.formatApiDate(from), 'toDate': Leave.formatApiDate(to), 'reason': reason});
  }

  Future<void> update(int id, {required DateTime from, required DateTime to, required String reason}) async {
    await _api.put('/api/leaves/$id', body: {'fromDate': Leave.formatApiDate(from), 'toDate': Leave.formatApiDate(to), 'reason': reason});
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/leaves/$id');
  }

  Future<void> review(int id, {required bool approve}) async {
    await _api.post('/api/leaves/$id/review', body: {'approve': approve});
  }
}
