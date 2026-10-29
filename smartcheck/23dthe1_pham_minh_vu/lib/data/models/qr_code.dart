/// Mã QR động do `GET /api/qr/current` trả về.
class QrCodeInfo {
  const QrCodeInfo({required this.token, required this.ttlSeconds, required this.location});

  final String token;
  final int ttlSeconds;
  final String location;

  factory QrCodeInfo.fromJson(Map<String, dynamic> j) => QrCodeInfo(
        token: j['token'] as String,
        ttlSeconds: (j['ttlSeconds'] as num).toInt(),
        location: (j['location'] ?? '') as String,
      );
}
