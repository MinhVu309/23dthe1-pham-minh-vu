import '../../core/api_client.dart';
import '../models/paged_result.dart';
import '../models/shift.dart';

/// Giờ truyền vào dạng `HH:mm:ss` (xem [Shift.formatApi]).
class ShiftRepository {
  ShiftRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<Shift>> list({int page = 1, int pageSize = 200}) async =>
      PagedResult.fromJson(await _api.get('/api/shifts', query: {'page': page, 'pageSize': pageSize}), Shift.fromJson);

  Map<String, dynamic> _body(String name, String start, String end, int tolerance) => {
        'name': name,
        'startTime': start,
        'endTime': end,
        'lateToleranceMinutes': tolerance,
      };

  Future<Shift> create({required String name, required String start, required String end, required int lateToleranceMinutes}) async =>
      Shift.fromJson(((await _api.post('/api/shifts', body: _body(name, start, end, lateToleranceMinutes))) as Map).cast());

  Future<void> update(int id, {required String name, required String start, required String end, required int lateToleranceMinutes}) async {
    await _api.put('/api/shifts/$id', body: _body(name, start, end, lateToleranceMinutes));
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/shifts/$id');
  }
}
