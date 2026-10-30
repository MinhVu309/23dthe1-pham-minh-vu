import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/secure_store.dart';
import 'core/theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/department_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/fraud_repository.dart';
import 'data/repositories/leave_repository.dart';
import 'data/repositories/location_repository.dart';
import 'data/repositories/qr_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'features/auth/auth_controller.dart';
import 'services/biometric_service.dart';
import 'services/device_id.dart';
import 'services/google_auth_service.dart';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  late final AuthController auth;
  final api = ApiClient(tokenProvider: () => auth.token);
  final repo = AuthRepository(api);
  final deviceId = StoredDeviceId();
  auth = AuthController(
    api: repo,
    store: SecureSessionStore(),
    google: GoogleAuthService(),
    biometric: DeviceBiometricVault(),
    deviceId: deviceId,
  );
  api.onUnauthorized = auth.handleUnauthorized;
  auth.restore();

  runApp(SmartCheckApp(auth: auth, api: api, authApi: repo, deviceId: deviceId));
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key, required this.auth, required this.api, required this.authApi, this.deviceId});

  final AuthController auth;
  final ApiClient api;
  final AuthApi authApi;
  final DeviceIdProvider? deviceId;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<ApiClient>.value(value: api),
        Provider<AuthApi>.value(value: authApi),
        Provider<EmployeeRepository>(create: (_) => EmployeeRepository(api)),
        Provider<DepartmentRepository>(create: (_) => DepartmentRepository(api)),
        Provider<ShiftRepository>(create: (_) => ShiftRepository(api)),
        Provider<LocationRepository>(create: (_) => LocationRepository(api)),
        Provider<LeaveRepository>(create: (_) => LeaveRepository(api)),
        Provider<QrRepository>(create: (_) => QrRepository(api)),
        Provider<FraudRepository>(create: (_) => FraudRepository(api)),
        Provider<AttendanceRepository>(create: (_) => AttendanceRepository(api)),
        Provider<DeviceIdProvider>(create: (_) => deviceId ?? StoredDeviceId()),
        Provider<LocationProvider>(create: (_) => GeolocatorLocationProvider()),
      ],
      child: MaterialApp(
        title: 'SmartCheck',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
