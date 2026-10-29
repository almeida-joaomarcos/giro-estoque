import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/db/app_database.dart';
import '../core/utils/formatters.dart';
import '../core/utils/seed_data.dart';
import '../data/inventory_repository.dart';
import '../domain/models/business_config.dart';
import '../domain/models/product.dart';
import '../domain/models/product_stock.dart';
import '../domain/models/segment.dart';
import '../domain/models/stock_location.dart';
import '../domain/models/stock_movement.dart';

/// Estado único do app: configuração, produtos com saldo e movimentações.
class InventoryController extends ChangeNotifier {
  InventoryController({InventoryRepository? repository})
      : _repository = repository ?? InventoryRepository(AppDatabase.instance);

  final InventoryRepository _repository;

  BusinessConfig? _config;
  List<StockLocation> _locations = const [];
  List<ProductStock> _products = const [];
  List<StockMovement> _movements = const [];
  List<CategoryStock> _categories = const [];
  StockSummary _summary = StockSummary.empty;
  String _search = '';
  bool _loading = true;
  bool _busy = false;
  String? _lastError;

  bool get loading => _loading;
  bool get busy => _busy;
  String? get lastError => _lastError;
  String get search => _search;

  BusinessConfig? get config => _config;
  Segment get segment => _config?.segment ?? Segment.mercado;
  List<StockLocation> get locations => _locations;
  List<StockMovement> get recentMovements => _movements;
  List<CategoryStock> get categories => _categories;
  StockSummary get summary => _summary;
  List<ProductStock> get allProducts => _products;

  bool get onboarded => _config?.isConfigured ?? false;

  List<ProductStock> get products {
    final term = _search.trim().toLowerCase();
    if (term.isEmpty) return _products;
    return _products.where((item) {
      final product = item.product;
      return product.name.toLowerCase().contains(term) ||
          (product.sku ?? '').toLowerCase().contains(term) ||
          (product.barcode ?? '').toLowerCase().contains(term) ||
          (product.category ?? '').toLowerCase().contains(term);
    }).toList();
  }

  List<ProductStock> get criticalProducts =>
      _products.where((item) => item.isCritical).toList()
        ..sort((a, b) => a.balance.compareTo(b.balance));

  StockLocation get defaultLocation {
    for (final location in _locations) {
      if (location.isDefault) return location;
    }
    if (_locations.isNotEmpty) return _locations.first;
    return const StockLocation(id: 0, name: 'Principal', isDefault: true);
  }

  String _locationName(int id) {
    for (final location in _locations) {
      if (location.id == id) return location.name;
    }
    return 'este local';
  }

  Future<double> balanceAt(int productId, int locationId) =>
      _repository.readBalanceAt(productId, locationId);

  List<String> get categoriesInUse {
    final values = <String>{};
    for (final item in _products) {
      final category = item.product.category?.trim();
      if (category != null && category.isNotEmpty) values.add(category);
    }
    final list = values.toList()..sort();
    return list;
  }

  /* -----------------------------------------------------------------------
     Carregamento
     ----------------------------------------------------------------------- */

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _config = await _repository.readConfig();
      await _reload();
      _lastError = null;
    } catch (error) {
      _lastError = 'Não foi possível carregar os dados: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    if (_config == null || !_config!.isConfigured) {
      _locations = const [];
      _products = const [];
      _movements = const [];
      _categories = const [];
      _summary = StockSummary.empty;
      return;
    }

    _locations = await _repository.readLocations();
    _products = await _repository.readProducts();
    _movements = await _repository.readMovements(limit: 120);
    _categories = _buildCategories(_products);
    _summary = await _buildSummary(_products);
  }

  Future<void> _refresh() async {
    await _reload();
    notifyListeners();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  /* -----------------------------------------------------------------------
     Onboarding e configuração
     ----------------------------------------------------------------------- */

  Future<void> completeOnboarding({
    required String businessName,
    required Segment segment,
    bool withSampleData = true,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final config = BusinessConfig(
        businessName: businessName.trim(),
        segment: segment,
        tracksBatch: segment.tracksBatch,
        tracksExpiry: segment.tracksExpiry,
        multiLocation: segment.multiLocation,
        createdAt: DateTime.now(),
      );
      await _repository.saveConfig(config);
      _config = config;
      _locations = await _repository.readLocations();

      if (segment.multiLocation) {
        await _repository.insertLocation('Depósito');
        await _repository.insertLocation('Loja');
      }

      if (withSampleData) {
        await _seed(segment);
      }

      await _reload();
    } catch (error) {
      _lastError = 'Não foi possível concluir a configuração: $error';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateConfig(BusinessConfig config) async {
    await _repository.saveConfig(config);
    _config = config;
    await _refresh();
  }

  Future<void> addLocation(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repository.insertLocation(trimmed);
    await _refresh();
  }

  Future<void> removeLocation(int id) async {
    if (_locations.length <= 1) {
      throw StateError('É preciso manter pelo menos um local.');
    }
    await _repository.deleteLocation(id);
    await _refresh();
  }

  Future<void> _seed(Segment segment) async {
    final locationId = defaultLocation.id;
    if (locationId == null || locationId == 0) return;

    final now = DateTime.now();
    for (final seed in seedProductsFor(segment)) {
      final id = await _repository.insertProduct(
        Product(
          name: seed.name,
          category: seed.category,
          unit: seed.unit,
          costPrice: seed.cost,
          salePrice: seed.sale,
          minStock: seed.minStock,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _repository.insertMovement(
        StockMovement(
          productId: id,
          type: MovementType.entrada,
          quantity: seed.initial,
          unitCost: seed.cost,
          locationId: locationId,
          reason: 'Estoque inicial',
          createdAt: now.subtract(const Duration(days: 9)),
        ),
      );

      if (seed.weeklyOut > 0) {
        await _repository.insertMovement(
          StockMovement(
            productId: id,
            type: MovementType.saida,
            quantity: seed.weeklyOut,
            unitCost: seed.cost,
            locationId: locationId,
            reason: 'Vendas da semana',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
        );
      }
    }
  }

  /* -----------------------------------------------------------------------
     Produtos
     ----------------------------------------------------------------------- */

  Future<int> createProduct(Product product) async {
    final id = await _repository.insertProduct(product);
    await _refresh();
    return id;
  }

  Future<void> updateProduct(Product product) async {
    await _repository.updateProduct(product);
    await _refresh();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    await _refresh();
  }

  Future<double> balanceOf(int productId) => _repository.readBalance(productId);

  /* -----------------------------------------------------------------------
     Movimentações
     ----------------------------------------------------------------------- */

  Future<void> registerMovement({
    required Product product,
    required MovementType type,
    required double quantity,
    required int locationId,
    double unitCost = 0,
    String? reason,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Informe uma quantidade maior que zero.');
    }
    if (type == MovementType.ajuste) {
      throw ArgumentError('Use adjustStock para ajustes de inventário.');
    }

    if (!type.isInbound) {
      final available =
          await _repository.readBalanceAt(product.id!, locationId);
      if (quantity > available) {
        throw ArgumentError(
          'Saldo insuficiente em ${_locationName(locationId)}: existem '
          '${formatQuantityWithUnit(available, product.unit)} disponíveis.',
        );
      }
    }

    await _repository.insertMovement(
      StockMovement(
        productId: product.id!,
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        locationId: locationId,
        reason: reason,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    await _refresh();
  }

  /// Ajuste de inventário: o usuário informa a quantidade contada.
  Future<void> adjustStock({
    required Product product,
    required double counted,
    required int locationId,
    String? note,
  }) async {
    final current = await _repository.readBalanceAt(product.id!, locationId);
    final delta = counted - current;

    if (delta == 0) {
      throw StateError('O saldo já é exatamente esse valor.');
    }

    await _repository.insertMovement(
      StockMovement(
        productId: product.id!,
        type: MovementType.ajuste,
        quantity: delta,
        unitCost: product.costPrice,
        locationId: locationId,
        reason: 'Ajuste de inventário',
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    await _refresh();
  }

  Future<void> registerTransfer({
    required Product product,
    required double quantity,
    required int fromLocationId,
    required int toLocationId,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Informe uma quantidade maior que zero.');
    }
    if (fromLocationId == toLocationId) {
      throw ArgumentError('Escolha locais diferentes.');
    }

    final available = await _repository.readBalanceAt(
      product.id!,
      fromLocationId,
    );
    if (quantity > available) {
      throw ArgumentError(
        'Saldo insuficiente em ${_locationName(fromLocationId)}: existem '
        '${formatQuantityWithUnit(available, product.unit)} disponíveis.',
      );
    }

    await _repository.insertTransfer(
      productId: product.id!,
      quantity: quantity,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      note: note,
    );
    await _refresh();
  }

  /* -----------------------------------------------------------------------
     Relatórios e arquivos
     ----------------------------------------------------------------------- */

  Future<List<StockMovement>> movementsForProduct(int productId) {
    return _repository.readMovements(productId: productId, limit: 100);
  }

  Future<String> exportCsv() async {
    final folder = await _documentsFolder();
    final file = File(p.join(folder.path, 'estoque-${_stamp()}.csv'));

    final rows = <List<Object?>>[
      [
        'Nome',
        'SKU',
        'CodigoBarras',
        'Categoria',
        'Unidade',
        'Custo',
        'Preco',
        'EstoqueMinimo',
        'Saldo',
      ],
      ..._products.map(
        (item) => [
          item.product.name,
          item.product.sku ?? '',
          item.product.barcode ?? '',
          item.product.category ?? '',
          item.product.unit,
          item.product.costPrice.toStringAsFixed(2),
          item.product.salePrice.toStringAsFixed(2),
          item.product.minStock.toStringAsFixed(3),
          item.balance.toStringAsFixed(3),
        ],
      ),
    ];

    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file.path;
  }

  Future<int> importCsv(String path) async {
    final content = await File(path).readAsString();
    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(content);

    if (rows.length < 2) return 0;

    final header =
        rows.first.map((cell) => cell.toString().trim().toLowerCase()).toList();

    int column(String name, {int fallback = -1}) {
      final index = header.indexOf(name);
      return index >= 0 ? index : fallback;
    }

    final nameCol = column('nome');
    if (nameCol < 0) {
      throw FormatException('A planilha precisa de uma coluna "Nome".');
    }

    final skuCol = column('sku');
    final barcodeCol = column('codigobarras');
    final categoryCol = column('categoria');
    final unitCol = column('unidade');
    final costCol = column('custo');
    final priceCol = column('preco');
    final minCol = column('estoqueminimo');
    final balanceCol = column('saldo');

    String cell(List<dynamic> row, int index) {
      if (index < 0 || index >= row.length) return '';
      return row[index].toString().trim();
    }

    double number(List<dynamic> row, int index) {
      return parseNumber(cell(row, index)) ?? 0;
    }

    final locationId = defaultLocation.id ?? 0;
    var imported = 0;

    for (final row in rows.skip(1)) {
      final name = cell(row, nameCol);
      if (name.isEmpty) continue;

      final productId = await _repository.insertProduct(
        Product(
          name: name,
          sku: cell(row, skuCol),
          barcode: cell(row, barcodeCol),
          category: cell(row, categoryCol),
          unit: cell(row, unitCol).isEmpty ? 'un' : cell(row, unitCol),
          costPrice: number(row, costCol),
          salePrice: number(row, priceCol),
          minStock: number(row, minCol),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final balance = number(row, balanceCol);
      if (balance > 0 && locationId != 0) {
        await _repository.insertMovement(
          StockMovement(
            productId: productId,
            type: MovementType.entrada,
            quantity: balance,
            unitCost: number(row, costCol),
            locationId: locationId,
            reason: 'Importação de planilha',
            createdAt: DateTime.now(),
          ),
        );
      }

      imported++;
    }

    await _refresh();
    return imported;
  }

  Future<String> backupDatabase() async {
    final folder = await _documentsFolder();
    final target = File(p.join(folder.path, 'backup-${_stamp()}.db'));
    await _repository.backupTo(target.path);
    return target.path;
  }

  Future<void> restoreDatabase(String sourcePath) async {
    final databasePath = AppDatabase.instance.path;
    await AppDatabase.instance.close();
    try {
      await File(sourcePath).copy(databasePath);
    } finally {
      // Reabre mesmo se a cópia falhar, para o app não ficar sem banco.
      await AppDatabase.instance.init(overridePath: databasePath);
    }
    _config = await _repository.readConfig();
    await _refresh();
  }

  Future<void> resetAll() async {
    await _repository.clearAll();
    _config = null;
    await _reload();
    notifyListeners();
  }

  Future<Directory> _documentsFolder() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(documents.path, 'Giro'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  String _stamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '${now.year}$month$day-$hour$minute';
  }

  List<CategoryStock> _buildCategories(List<ProductStock> products) {
    final totals = <String, CategoryStock>{};
    for (final item in products) {
      final raw = item.product.category?.trim();
      final key = (raw == null || raw.isEmpty) ? 'Sem categoria' : raw;
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

  Future<StockSummary> _buildSummary(List<ProductStock> products) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final movementsToday = await _repository.readMovementsCount(today);
    final movementsWeek = await _repository.readMovementsCount(weekStart);

    var units = 0.0;
    var value = 0.0;
    var low = 0;
    var out = 0;

    for (final item in products) {
      units += item.balance;
      if (item.balance > 0) value += item.stockValue;
      if (item.isOutOfStock) {
        out++;
      } else if (item.isLowStock) {
        low++;
      }
    }

    return StockSummary(
      totalProducts: products.length,
      totalUnits: units,
      totalValue: value,
      lowStockCount: low,
      outOfStockCount: out,
      movementsToday: movementsToday,
      movementsWeek: movementsWeek,
    );
  }
}
