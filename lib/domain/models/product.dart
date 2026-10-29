/// Produto cadastrado. O saldo **não** fica aqui: ele é calculado a partir
/// das movimentações, para nunca ficar inconsistente.
class Product {
  const Product({
    this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.category,
    this.unit = 'un',
    this.costPrice = 0,
    this.salePrice = 0,
    this.minStock = 0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? category;
  final String unit;
  final double costPrice;
  final double salePrice;
  final double minStock;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? costPrice,
    double? salePrice,
    double? minStock,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      minStock: minStock ?? this.minStock,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      unit: (map['unit'] as String?) ?? 'un',
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'name': name.trim(),
      'sku': _emptyToNull(sku),
      'barcode': _emptyToNull(barcode),
      'category': _emptyToNull(category),
      'unit': unit,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'min_stock': minStock,
      'active': active ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': now,
    };
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
