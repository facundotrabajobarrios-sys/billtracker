// 📂 Modelo de Categoría para clasificar facturas
class Category {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.createdAt,
  });

  // 📥 Crear desde JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '', // ✅ Si es null, usa ''
      name:
          json['name'] ?? 'Sin categoría', // ✅ Si es null, usa 'Sin categoría'
      icon: json['icon'],
      color: json['color'],
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
      'icon': icon,
      'color': color,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // 🎨 Categorías predefinidas
  static List<Category> getDefaultCategories() {
    return [
      Category(id: '1', name: 'Servicios', icon: '🏠', color: '#FF6B6B'),
      Category(id: '2', name: 'Préstamos', icon: '💰', color: '#4ECDC4'),
      Category(id: '3', name: 'Suscripciones', icon: '📱', color: '#45B7D1'),
      Category(id: '4', name: 'Tarjetas', icon: '💳', color: '#96CEB4'),
      Category(id: '5', name: 'Otros', icon: '📌', color: '#FFEAA7'),
    ];
  }
}
