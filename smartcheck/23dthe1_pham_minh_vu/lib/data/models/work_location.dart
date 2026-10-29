class WorkLocation {
  const WorkLocation({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shiftId,
  });

  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final int shiftId;

  factory WorkLocation.fromJson(Map<String, dynamic> j) => WorkLocation(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        address: j['address'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusMeters: (j['radiusMeters'] as num).toInt(),
        shiftId: (j['shiftId'] as num).toInt(),
      );
}
