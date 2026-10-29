import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../../domain/models/business_config.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_stock.dart';
import '../../domain/models/stock_location.dart';
import '../../domain/models/stock_movement.dart';

/// Todo o acesso a dados do app passa por aqui. A UI nunca escreve SQL.
class InventoryRepository {
  InventoryRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Database get _db => _appDatabase.db;

  static const String _productSelect = '''
    SELECT p.*,
      COALESCE(SUM(CASE
        WHEN m.type IN ('entrada', 'transferencia_entrada') THEN m.quantity
        WHEN m.type IN ('saida', 'perda', 'transferencia_saida') THEN -ABS(m.quantity)
        WHEN m.type = 'ajuste' THEN m.quantity
        ELSE 0
      END), 0) AS balance
    FROM products p
    LEFT JOIN movements m ON m.product_id = p.id
  ''';

  /* ---------------------------------------------------------------------
     Configuração
     --------------------------------------------------------------------- */

  Future<BusinessConfig?> readConfig() async {
    final rows = await _db.query('business_config', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return BusinessConfig.fromMap(rows.first);
  }

  Future<void> saveConfig(BusinessConfig config) async {
    await _db.insert(
      'business_config',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /* ---------------------------------------------------------------------
     Locais
     --------------------------------------------------------------------- */

  Future<List<StockLocation>> readLocations() async {
    final rows = await _db.query(
      'locations',
      orderBy: 'is_default DESC, name COLLATE NOCASE',
    );
    return rows.map(StockLocation.fromMap).toList();
  }

  Future<int> insertLocation(String name) async {
    return _db.insert('locations', {'name': name.trim(), 'is_default': 0});
  }

  Future<void> deleteLocation(int id) async {
    await _db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }

  /* ---------------------------------------------------------------------
     Produtos
     --------------------------------------------------------------------- */

  Future<List<ProductStock>> readProducts({String? search}) async {
    final term = search?.trim();
    final hasSearch = term != null && term.isNotEmpty;

    final buffer = StringBuffer(_productSelect);
    final args = <Object?>[];

    if (hasSearch) {
      buffer.write('''
        WHERE p.name LIKE ? OR IFNULL(p.barcode, '') LIKE ?
          OR IFNULL(p.sku, '') LIKE ? OR IFNULL(p.category, '') LIKE ?
      ''');
      final like = '%$term%';
      args.addAll([like, like, like, like]);
    }

    buffer.write(' GROUP BY p.id ORDER BY p.name COLLATE NOCASE');

    final rows = await _db.rawQuery(buffer.toString(), args);
    return rows
        .map(
          (row) => ProductStock(
            product: Product.fromMap(row),
            balance: (row['balance'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  Future<ProductStock?> readProduct(int id) async {
    final rows = await _db.rawQuery(
      '$_productSelect WHERE p.id = ? GROUP BY p.id',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ProductStock(
      product: Product.fromMap(row),
      balance: (row['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<int> insertProduct(Product product) async {
    return _db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final id = product.id;
    if (id == null) {
      throw ArgumentError('Produto sem id não pode ser atualizado.');
    }
    await _db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(int id) async {
    await _db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> readBalance(int productId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN type IN ('entrada', 'transferencia_entrada') THEN quantity
        WHEN type IN ('saida', 'perda', 'transferencia_saida') THEN -ABS(quantity)
        WHEN type = 'ajuste' THEN quantity
        ELSE 0
      END), 0) AS balance
      FROM movements WHERE product_id = ?
      ''',
      [productId],
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  /// Saldo de um produto em um local específico (usado nas transferências).
  Future<double> readBalanceAt(int productId, int locationId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN type IN ('entrada', 'transferencia_entrada') THEN quantity
        WHEN type IN ('saida', 'perda', 'transferencia_saida') THEN -ABS(quantity)
        WHEN type = 'ajuste' THEN quantity
        ELSE 0
      END), 0) AS balance
      FROM movements WHERE product_id = ? AND location_id = ?
      ''',
      [productId, locationId],
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  /* ---------------------------------------------------------------------
     Movimentações
     --------------------------------------------------------------------- */

  Future<List<StockMovement>> readMovements({
    int limit = 200,
    int? productId,
  }) async {
    final buffer = StringBuffer('''
      SELECT m.*, p.name AS product_name,
             l.name AS location_name,
             t.name AS target_location_name
      FROM movements m
      JOIN products p ON p.id = m.product_id
      LEFT JOIN locations l ON l.id = m.location_id
      LEFT JOIN locations t ON t.id = m.target_location_id
    ''');

    final args = <Object?>[];
    if (productId != null) {
      buffer.write(' WHERE m.product_id = ?');
      args.add(productId);
    }

    buffer.write(' ORDER BY m.created_at DESC, m.id DESC LIMIT ?');
    args.add(limit);

    final rows = await _db.rawQuery(buffer.toString(), args);
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> insertMovement(StockMovement movement) async {
    return _db.insert('movements', movement.toMap());
  }

  /// Grava a transferência como duas linhas: saída na origem e entrada no
  /// destino. Assim o saldo por local continua correto.
  Future<void> insertTransfer({
    required int productId,
    required double quantity,
    required int fromLocationId,
    required int toLocationId,
    String? note,
    DateTime? createdAt,
  }) async {
    final when = createdAt ?? DateTime.now();
    final batch = _db.batch();
    batch.insert(
      'movements',
      StockMovement(
        productId: productId,
        type: MovementType.transferenciaSaida,
        quantity: quantity.abs(),
        locationId: fromLocationId,
        targetLocationId: toLocationId,
        note: note,
        createdAt: when,
      ).toMap(),
    );
    batch.insert(
      'movements',
      StockMovement(
        productId: productId,
        type: MovementType.transferenciaEntrada,
        quantity: quantity.abs(),
        locationId: toLocationId,
        targetLocationId: fromLocationId,
        note: note,
        createdAt: when,
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  Future<int> readMovementsCount(DateTime since) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM movements WHERE created_at >= ?',
      [since.toIso8601String()],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<CategoryStock>> readStockByCategory() async {
    final products = await readProducts();
    final totals = <String, CategoryStock>{};

    for (final item in products) {
      final key = (item.product.category == null ||
              item.product.category!.trim().isEmpty)
          ? 'Sem categoria'
          : item.product.category!.trim();
      final current = totals[key] ?? CategoryStock(category: key);
      totals[key] = CategoryStock(
        category: key,
        items: current.items + 1,
        quantity: current.quantity + item.balance,
        value: current.value + item.stockValue,
      );
    }

    final list = totals.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /* ---------------------------------------------------------------------
     Manutenção
     --------------------------------------------------------------------- */

  Future<void> clearAll() async {
    final batch = _db.batch();
    batch.delete('movements');
    batch.delete('products');
    batch.delete('locations');
    batch.delete('business_config');
    await batch.commit(noResult: true);
    await _db.insert('locations', {'name': 'Principal', 'is_default': 1});
  }

  /// Backup consistente do banco, mesmo com o app aberto.
  Future<void> backupTo(String path) async {
    await _db.execute('VACUUM INTO ?', [path]);
  }
}

/// Agrupamento de estoque por categoria (relatório).
class CategoryStock {
  const CategoryStock({
    required this.category,
    this.items = 0,
    this.quantity = 0,
    this.value = 0,
  });

  final String category;
  final int items;
  final double quantity;
  final double value;
}
