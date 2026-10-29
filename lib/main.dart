import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'state/inventory_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.init();

  final controller = InventoryController();
  await controller.load();

  runApp(
    ChangeNotifierProvider<InventoryController>.value(
      value: controller,
      child: const GiroApp(),
    ),
  );
}
