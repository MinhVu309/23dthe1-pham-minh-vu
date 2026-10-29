class Department {
  const Department({required this.id, required this.name, this.description});

  final int id;
  final String name;
  final String? description;

  factory Department.fromJson(Map<String, dynamic> j) =>
      Department(id: (j['id'] as num).toInt(), name: (j['name'] ?? '') as String, description: j['description'] as String?);
}
