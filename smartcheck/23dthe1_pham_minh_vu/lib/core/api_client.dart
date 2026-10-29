import 'package:dio/dio.dart';

import 'config.dart';

/// Lỗi đã được chuyển thành thông báo tiếng Việt thân thiện.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code, this.reasons = const []});

  final String message;
  final int? status;

  /// Mã nghiệp vụ của server, ví dụ `QR_INVALID`, `OUT_OF_RANGE`.
  final String? code;
  final List<String> reasons;

  bool get isNetwork => status == null;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Máy chủ phản hồi quá chậm, hãy thử lại sau ít giây.');
      case DioExceptionType.connectionError:
        return ApiException('Không kết nối được máy chủ. Kiểm tra mạng của bạn.');
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(e.response!);
      default:
        return ApiException('Không kết nối được máy chủ. Kiểm tra mạng của bạn.');
    }
  }

  factory ApiException._fromResponse(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    final data = r.data;
    String? message;
    String? code;
    var reasons = <String>[];

    if (data is Map) {
      if (data['message'] is String) message = data['message'] as String;
      if (data['code'] is String) code = data['code'] as String;
      if (data['reasons'] is List) {
        reasons = (data['reasons'] as List).map((e) => '$e').toList();
      }
      // Identity trả `{errors: [...]}`, validation của model trả `{errors: {Field: [...]}}`.
      if (message == null && data['errors'] != null) {
        final errors = data['errors'];
        final lines = errors is Map
            ? errors.values.expand((v) => v is List ? v : [v]).map((e) => '$e')
            : errors is List
                ? errors.map((e) => '$e')
                : const <String>[];
        final text = lines.map(_translate).toSet().join('\n');
        if (text.isNotEmpty) message = text;
      }
    }

    message ??= switch (status) {
      401 => 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu yêu cầu.',
      409 => 'Dữ liệu bị xung đột, hãy tải lại rồi thử lại.',
      >= 500 => 'Máy chủ đang gặp sự cố (HTTP $status), thử lại sau.',
      _ => 'Yêu cầu không thành công (HTTP $status).',
    };
    return ApiException(message, status: status, code: code, reasons: reasons);
  }

  /// Dịch các lỗi tiếng Anh thường gặp của Identity/validation; không khớp thì giữ nguyên.
  static String _translate(String m) {
    final l = m.toLowerCase();
    if (l.contains('already taken')) return 'Email này đã được đăng ký.';
    if (l.contains('at least one digit')) return 'Mật khẩu cần ít nhất một chữ số.';
    if (l.contains('at least one lowercase')) return 'Mật khẩu cần ít nhất một chữ thường.';
    if (l.contains('at least one uppercase')) return 'Mật khẩu cần ít nhất một chữ hoa.';
    if (l.contains('non alphanumeric')) return 'Mật khẩu cần ít nhất một ký tự đặc biệt.';
    if (l.contains('password') && (l.contains('at least 6') || l.contains("minimum length"))) {
      return 'Mật khẩu tối thiểu 6 ký tự.';
    }
    if (l.contains('not a valid e-mail') || l.contains('invalid email')) return 'Email không hợp lệ.';
    if (l.contains('fullname') && l.contains('required')) return 'Nhập họ và tên.';
    return m;
  }

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Gọi API: gắn JWT, đổi lỗi dio thành [ApiException], báo 401 cho tầng trên.
/// Không ghi log request/response để JWT, OTP không lọt ra console.
class ApiClient {
  ApiClient({
    required String? Function() tokenProvider,
    Dio? dio,
    String? baseUrl,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl ?? AppConfig.baseUrl
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers['Accept'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        // Chỉ coi là "phiên hết hạn" khi request có kèm JWT; login sai mật khẩu cũng 401 nhưng không có JWT.
        final hadToken = e.requestOptions.headers.containsKey('Authorization');
        if (e.response?.statusCode == 401 && hadToken) onUnauthorized?.call();
        handler.next(e);
      },
    ));
  }

  final Dio _dio;

  /// Được gọi khi server trả 401 cho request có JWT.
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _run(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _run(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _run(() => _dio.delete<dynamic>(path));

  Future<dynamic> _run(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
