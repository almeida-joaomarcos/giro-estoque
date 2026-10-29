/// Local físico onde o estoque fica (depósito, loja, caminhão).
class StockLocation {
  const StockLocation({
    this.id,
    required this.name,
    this.isDefault = false,
  });

  final int? id;
  final String name;
  final bool isDefault;

  factory StockLocation.fromMap(Map<String, Object?> map) {
    return StockLocation(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name.trim(),
        'is_default': isDefault ? 1 : 0,
      };
}
