import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

/// Acesso único ao banco SQLite local.
///
/// No Windows/Linux o plugin nativo do sqflite não existe, então usamos o
/// backend FFI. No Android/iOS o plugin normal é usado.
class AppDatabase {
  AppDatabase._();

  /// Usado apenas em testes, com um banco em memória já aberto.
  AppDatabase.forTesting(Database database)
      : _db = database,
        _path = ':memory:';

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 1;

  Database? _db;
  String? _path;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Banco de dados não inicializado. Chame init() antes.');
    }
    return database;
  }

  String get path => _path ?? '';

  bool get isOpen => _db != null;

  Future<void> init({String? overridePath}) async {
    if (_db != null) return;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final file = overridePath ?? p.join(await _directory(), 'giro_estoque.db');
    _path = file;

    _db = await openDatabase(
      file,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => createSchema(db),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<String> _directory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getDatabasesPath();
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'giro'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Cria o esquema. Público para permitir testes com banco em memória.
  static Future<void> createSchema(Database db, [int version = 1]) async {
    await db.execute('''
      CREATE TABLE business_config (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL,
        segment TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'BRL',
        tracks_batch INTEGER NOT NULL DEFAULT 0,
        tracks_expiry INTEGER NOT NULL DEFAULT 0,
        multi_location INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        category TEXT,
        unit TEXT NOT NULL DEFAULT 'un',
        cost_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0,
        location_id INTEGER NOT NULL,
        target_location_id INTEGER,
        reason TEXT,
        note TEXT,
        batch_code TEXT,
        expiry_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_movements_product ON movements(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_movements_created ON movements(created_at)',
    );
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

    await db.insert('locations', {'name': 'Principal', 'is_default': 1});
  }
}
