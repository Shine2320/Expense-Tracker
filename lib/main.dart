import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/datasources/hive_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveStorage.init();

  runApp(
    const ProviderScope(
      child: ExpenseTrackerApp(),
    ),
  );
}
