import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/hive_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveStorage.init();
  await SharedPreferences.getInstance();

  runApp(
    const ProviderScope(
      child: ExpenseTrackerApp(),
    ),
  );
}
