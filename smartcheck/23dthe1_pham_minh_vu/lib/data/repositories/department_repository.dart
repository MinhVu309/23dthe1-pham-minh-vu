import '../../core/api_client.dart';
import '../models/department.dart';
import '../models/paged_result.dart';

class DepartmentRepository {
  DepartmentRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<Department>> list({int page = 1, int pageSize = 200}) async =>
      PagedResult.fromJson(await _api.get('/api/departments', query: {'page': page, 'pageSize': pageSize}), Department.fromJson);

  Future<Department> create({required String name, String? description}) async =>
      Department.fromJson(((await _api.post('/api/departments', body: {'name': name, 'description': description})) as Map).cast());

  Future<void> update(int id, {required String name, String? description}) async {
    await _api.put('/api/departments/$id', body: {'name': name, 'description': description});
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/departments/$id');
  }
}
