import '../../core/api_client.dart';
import '../models/employee.dart';
import '../models/paged_result.dart';
import '../models/session.dart';

class EmployeeRepository {
  EmployeeRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<Employee>> list({String? q, int? departmentId, int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _api.get('/api/employees', query: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'departmentId': ?departmentId,
          'page': page,
          'pageSize': pageSize,
        }),
        Employee.fromJson,
      );

  /// Có thêm `role` so với danh sách.
  Future<Employee> get(String id) async => Employee.fromJson(((await _api.get('/api/employees/$id')) as Map).cast());

  Future<void> create({
    required String email,
    required String password,
    required String fullName,
    String? employeeCode,
    int? departmentId,
    required UserRole role,
  }) async {
    await _api.post('/api/employees', body: {
      'email': email,
      'password': password,
      'fullName': fullName,
      'employeeCode': employeeCode,
      'departmentId': departmentId,
      'role': role.apiName,
    });
  }

  /// `role = null` giữ nguyên role hiện tại (server bỏ qua khi không phải Admin/Manager/Employee).
  Future<void> update(
    String id, {
    required String fullName,
    String? employeeCode,
    int? departmentId,
    UserRole? role,
    required bool isActive,
  }) async {
    await _api.put('/api/employees/$id', body: {
      'fullName': fullName,
      'employeeCode': employeeCode,
      'departmentId': departmentId,
      'role': role?.apiName,
      'isActive': isActive,
    });
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/employees/$id');
  }
}
