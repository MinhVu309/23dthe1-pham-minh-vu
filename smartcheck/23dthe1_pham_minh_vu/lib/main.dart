import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/secure_store.dart';
import 'core/settings.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(PrefsSettingsStore());
  await settings.load(); // đọc trước khi vẽ để không nháy từ giao diện mặc định sang giao diện đã chọn
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

  runApp(SmartCheckApp(auth: auth, api: api, authApi: repo, deviceId: deviceId, settings: settings));
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key, required this.auth, required this.api, required this.authApi, this.deviceId, this.settings});

  final AuthController auth;
  final ApiClient api;
  final AuthApi authApi;
  final DeviceIdProvider? deviceId;
  final SettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<SettingsController>.value(value: settings ?? SettingsController(MemorySettingsStore())),
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
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          title: 'SmartCheck',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: buildTheme(background: s.background),
          // Cỡ chữ người dùng chọn nhân với cỡ chữ hệ thống của máy (giới hạn 1.6 để giao diện không vỡ).
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = (mq.textScaler.scale(1) * s.textSize.factor).clamp(0.8, 1.6);
            return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
          },
          home: const AuthGate(),
        ),
      ),
    );
  }
}
