import 'package:flutter_test/flutter_test.dart';
import 'package:giro_estoque/core/db/app_database.dart';
import 'package:giro_estoque/data/inventory_repository.dart';
import 'package:giro_estoque/domain/models/business_config.dart';
import 'package:giro_estoque/domain/models/product.dart';
import 'package:giro_estoque/domain/models/segment.dart';
import 'package:giro_estoque/domain/models/stock_movement.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late InventoryRepository repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, version) => AppDatabase.createSchema(database),
      ),
    );
    repository = InventoryRepository(AppDatabase.forTesting(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertProduct(String name, {double minStock = 0}) {
    return repository.insertProduct(
      Product(
        name: name,
        category: 'Mercearia',
        unit: 'un',
        costPrice: 10,
        minStock: minStock,
      ),
    );
  }

  Future<void> insertMovement(
    int productId,
    MovementType type,
    double quantity, {
    int locationId = 1,
  }) {
    return repository.insertMovement(
      StockMovement(
        productId: productId,
        type: type,
        quantity: quantity,
        unitCost: 10,
        locationId: locationId,
        createdAt: DateTime.now(),
      ),
    );
  }

  group('saldo', () {
    test('entradas e saídas compõem o saldo do produto', () async {
      final id = await insertProduct('Arroz');
      await insertMovement(id, MovementType.entrada, 10);
      await insertMovement(id, MovementType.saida, 4);
      await insertMovement(id, MovementType.perda, 1);

      final products = await repository.readProducts();

      expect(products, hasLength(1));
      expect(products.single.balance, 5);
      expect(await repository.readBalance(id), 5);
    });

    test('ajuste soma delta positivo e negativo', () async {
      final id = await insertProduct('Feijão');
      await insertMovement(id, MovementType.entrada, 10);
      await insertMovement(id, MovementType.ajuste, -3);
      await insertMovement(id, MovementType.ajuste, 5);

      expect(await repository.readBalance(id), 12);
    });

    test('produto sem movimentação tem saldo zero', () async {
      await insertProduct('Novo');
      final products = await repository.readProducts();
      expect(products.single.balance, 0);
    });

    test('transferência preserva o total e move entre locais', () async {
      await db.insert('locations', {'name': 'Depósito', 'is_default': 0});
      final id = await insertProduct('Cerveja');
      await insertMovement(id, MovementType.entrada, 20);

      await repository.insertTransfer(
        productId: id,
        quantity: 8,
        fromLocationId: 1,
        toLocationId: 2,
      );

      expect(await repository.readBalance(id), 20);

      final movements = await repository.readMovements(productId: id);
      expect(movements, hasLength(3));
      expect(
        movements.where(
          (movement) => movement.type == MovementType.transferenciaSaida,
        ),
        hasLength(1),
      );
      expect(
        movements.where(
          (movement) => movement.type == MovementType.transferenciaEntrada,
        ),
        hasLength(1),
      );
    });

    test('saldo por local separa origem e destino na transferência', () async {
      await db.insert('locations', {'name': 'Loja', 'is_default': 0});
      final id = await insertProduct('Sabão');
      await insertMovement(id, MovementType.entrada, 10, locationId: 1);

      await repository.insertTransfer(
        productId: id,
        quantity: 4,
        fromLocationId: 1,
        toLocationId: 2,
      );

      expect(await repository.readBalanceAt(id, 1), 6);
      expect(await repository.readBalanceAt(id, 2), 4);
      expect(await repository.readBalance(id), 10);
    });

    test('produtos sem movimento entram no agrupamento por categoria',
        () async {
      await insertProduct('Óleo');
      final categories = await repository.readStockByCategory();
      expect(categories, hasLength(1));
      expect(categories.single.category, 'Mercearia');
      expect(categories.single.items, 1);
    });
  });

  group('busca', () {
    test('encontra por nome, categoria e código de barras', () async {
      await repository.insertProduct(
        Product(
          name: 'Refrigerante cola',
          barcode: '789123',
          sku: 'REF-1',
          category: 'Bebidas',
        ),
      );
      await insertProduct('Arroz');

      expect(await repository.readProducts(search: 'refri'), hasLength(1));
      expect(await repository.readProducts(search: 'Bebidas'), hasLength(1));
      expect(await repository.readProducts(search: '789123'), hasLength(1));
      expect(await repository.readProducts(search: 'inexistente'), isEmpty);
    });
  });

  group('configuração e locais', () {
    test('salva e lê a configuração uma única vez', () async {
      final config = BusinessConfig(
        businessName: 'Padaria Pão Quente',
        segment: Segment.padaria,
        tracksBatch: true,
        tracksExpiry: true,
        multiLocation: false,
      );

      await repository.saveConfig(config);
      await repository.saveConfig(config.copyWith(businessName: 'Padaria 2'));

      final stored = await repository.readConfig();
      expect(stored, isNotNull);
      expect(stored!.businessName, 'Padaria 2');
      expect(stored.segment, Segment.padaria);
    });

    test('cria local padrão na inicialização do esquema', () async {
      final locations = await repository.readLocations();
      expect(locations, hasLength(1));
      expect(locations.single.isDefault, isTrue);
    });

    test('limpar tudo mantém um local padrão', () async {
      await insertProduct('Arroz');
      await repository.clearAll();

      expect(await repository.readProducts(), isEmpty);
      expect(await repository.readConfig(), isNull);
      final locations = await repository.readLocations();
      expect(locations, hasLength(1));
      expect(locations.single.isDefault, isTrue);
    });
  });

  group('movimentações', () {
    test('mantém o nome do produto e do local na listagem', () async {
      final id = await insertProduct('Leite');
      await insertMovement(id, MovementType.entrada, 6);

      final movements = await repository.readMovements();
      expect(movements.single.productName, 'Leite');
      expect(movements.single.locationName, 'Principal');
    });

    test('conta movimentações a partir de uma data', () async {
      final id = await insertProduct('Café');
      await insertMovement(id, MovementType.entrada, 3);

      final today = DateTime.now().subtract(const Duration(days: 1));
      expect(await repository.readMovementsCount(today), 1);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(await repository.readMovementsCount(tomorrow), 0);
    });

    test('excluir produto remove suas movimentações', () async {
      final id = await insertProduct('Açúcar');
      await insertMovement(id, MovementType.entrada, 4);

      await repository.deleteProduct(id);

      expect(await repository.readMovements(), isEmpty);
    });
  });
}
