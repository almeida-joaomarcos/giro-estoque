/// Tipos de movimentação de estoque.
///
/// Transferência é gravada como duas linhas (saída na origem e entrada no
/// destino), o que mantém o histórico por local correto.
enum MovementType {
  entrada('entrada', 'Entrada', true),
  saida('saida', 'Saída', false),
  perda('perda', 'Perda', false),
  ajuste('ajuste', 'Ajuste', true),
  transferenciaSaida('transferencia_saida', 'Transferência (saída)', false),
  transferenciaEntrada(
      'transferencia_entrada', 'Transferência (entrada)', true);

  const MovementType(this.dbValue, this.label, this.isInbound);

  final String dbValue;
  final String label;
  final bool isInbound;

  /// Quanto essa movimentação soma (ou subtrai) do saldo.
  ///
  /// No ajuste a quantidade já vem com sinal (pode ser negativa).
  double signedQuantity(double quantity) {
    switch (this) {
      case MovementType.entrada:
      case MovementType.transferenciaEntrada:
        return quantity.abs();
      case MovementType.saida:
      case MovementType.perda:
      case MovementType.transferenciaSaida:
        return -quantity.abs();
      case MovementType.ajuste:
        return quantity;
    }
  }

  /// Tipos disponíveis no formulário manual.
  static const List<MovementType> manual = [
    MovementType.entrada,
    MovementType.saida,
    MovementType.perda,
    MovementType.ajuste,
  ];

  static MovementType fromDb(String value) {
    for (final type in MovementType.values) {
      if (type.dbValue == value) return type;
    }
    return MovementType.entrada;
  }
}

class StockMovement {
  const StockMovement({
    this.id,
    required this.productId,
    this.productName,
    required this.type,
    required this.quantity,
    this.unitCost = 0,
    required this.locationId,
    this.locationName,
    this.targetLocationId,
    this.targetLocationName,
    this.reason,
    this.note,
    this.batchCode,
    this.expiryDate,
    required this.createdAt,
  });

  final int? id;
  final int productId;
  final String? productName;
  final MovementType type;
  final double quantity;
  final double unitCost;
  final int locationId;
  final String? locationName;
  final int? targetLocationId;
  final String? targetLocationName;
  final String? reason;
  final String? note;
  final String? batchCode;
  final DateTime? expiryDate;
  final DateTime createdAt;

  double get signedQuantity => type.signedQuantity(quantity);
  double get totalCost => quantity.abs() * unitCost;

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String?,
      type: MovementType.fromDb((map['type'] as String?) ?? 'entrada'),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      locationId: map['location_id'] as int,
      locationName: map['location_name'] as String?,
      targetLocationId: map['target_location_id'] as int?,
      targetLocationName: map['target_location_name'] as String?,
      reason: map['reason'] as String?,
      note: map['note'] as String?,
      batchCode: map['batch_code'] as String?,
      expiryDate: DateTime.tryParse((map['expiry_date'] as String?) ?? ''),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'product_id': productId,
      'type': type.dbValue,
      'quantity': quantity,
      'unit_cost': unitCost,
      'location_id': locationId,
      'target_location_id': targetLocationId,
      'reason': _emptyToNull(reason),
      'note': _emptyToNull(note),
      'batch_code': _emptyToNull(batchCode),
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
