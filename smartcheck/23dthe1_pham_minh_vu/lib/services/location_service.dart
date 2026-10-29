import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/clock.dart';

/// Một lần đọc GPS. `isMocked` do hệ điều hành báo (Android `isMock`), gửi nguyên lên server.
class LocationReading {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
    required this.takenAt,
  });

  final double latitude;
  final double longitude;

  /// Sai số ước tính, mét.
  final double accuracy;
  final bool isMocked;
  final DateTime takenAt;
}

enum LocationProblem { serviceOff, denied, deniedForever, timeout, unavailable }

class LocationException implements Exception {
  const LocationException(this.problem);
  final LocationProblem problem;

  String get message => switch (problem) {
        LocationProblem.serviceOff => 'Dịch vụ vị trí (GPS) đang tắt. Hãy bật GPS rồi thử lại.',
        LocationProblem.denied => 'Cần quyền truy cập vị trí để xác định bạn có ở điểm chấm công không.',
        LocationProblem.deniedForever => 'Quyền vị trí đã bị chặn. Hãy bật lại trong Cài đặt của ứng dụng.',
        LocationProblem.timeout => 'Chưa lấy được vị trí. Hãy ra nơi thoáng hơn rồi thử lại.',
        LocationProblem.unavailable => 'Không đọc được vị trí của thiết bị.',
      };

  /// Có thể sửa bằng cách mở Cài đặt (bật GPS / cấp quyền).
  bool get needsSettings => problem == LocationProblem.serviceOff || problem == LocationProblem.deniedForever;

  String get settingsLabel => problem == LocationProblem.serviceOff ? 'Mở cài đặt vị trí' : 'Mở cài đặt ứng dụng';
}

abstract interface class LocationProvider {
  /// Ném [LocationException] khi không lấy được vị trí.
  Future<LocationReading> read();

  /// Mở màn Cài đặt phù hợp với [problem].
  Future<void> openSettings(LocationProblem problem);
}

class GeolocatorLocationProvider implements LocationProvider {
  @override
  Future<LocationReading> read() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const LocationException(LocationProblem.serviceOff);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) throw const LocationException(LocationProblem.deniedForever);
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      throw const LocationException(LocationProblem.denied);
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 20)),
      );
      return LocationReading(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        isMocked: p.isMocked,
        takenAt: nowProvider(),
      );
    } on TimeoutException {
      throw const LocationException(LocationProblem.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationProblem.serviceOff);
    } on PermissionDeniedException {
      throw const LocationException(LocationProblem.denied);
    } catch (_) {
      throw const LocationException(LocationProblem.unavailable);
    }
  }

  @override
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
