// 🏢 Modelo de Servicio (proveedor de factura)
class Service {
  final String id;
  final String name;
  final String? description;
  final String? logo;
  final DateTime? createdAt;

  Service({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    this.createdAt,
  });

  // 📥 Crear desde JSON
  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] ?? '', // ✅ Si es null, usa ''
      name: json['name'] ?? 'Sin nombre', // ✅ Si es null, usa 'Sin nombre'
      description: json['description'],
      logo: json['logo'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  // 📤 Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logo': logo,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // 🏢 Servicios predefinidos
  static List<Service> getDefaultServices() {
    return [
      Service(id: '1', name: 'ANDE', description: 'Electricidad'),
      Service(id: '2', name: 'COPACO', description: 'Agua'),
      Service(id: '3', name: 'Personal', description: 'Telefonía'),
      Service(id: '4', name: 'Tigo', description: 'Telefonía'),
      Service(id: '5', name: 'Netflix', description: 'Streaming'),
      Service(id: '6', name: 'Spotify', description: 'Música'),
    ];
  }
}
