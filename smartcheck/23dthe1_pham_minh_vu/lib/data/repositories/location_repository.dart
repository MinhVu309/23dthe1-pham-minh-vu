import '../../core/api_client.dart';
import '../models/paged_result.dart';
import '../models/work_location.dart';

class LocationRepository {
  LocationRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<WorkLocation>> list({int page = 1, int pageSize = 200}) async =>
      PagedResult.fromJson(await _api.get('/api/locations', query: {'page': page, 'pageSize': pageSize}), WorkLocation.fromJson);

  Map<String, dynamic> _body({
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int shiftId,
  }) =>
      {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'shiftId': shiftId,
      };

  Future<WorkLocation> create({
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int shiftId,
  }) async =>
      WorkLocation.fromJson(((await _api.post('/api/locations',
          body: _body(name: name, address: address, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters, shiftId: shiftId))) as Map)
          .cast());

  Future<void> update(
    int id, {
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int shiftId,
  }) async {
    await _api.put('/api/locations/$id',
        body: _body(name: name, address: address, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters, shiftId: shiftId));
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/locations/$id');
  }
}
