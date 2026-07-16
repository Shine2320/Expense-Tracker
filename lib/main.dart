import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/hive_storage.dart';
import 'data/repositories/expense_repository.dart';
import 'data/services/balance_migration.dart';
import 'presentation/providers/migration_notice_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: _AppWithSplash(),
    ),
  );
}

class _AppWithSplash extends ConsumerStatefulWidget {
  const _AppWithSplash();

  @override
  ConsumerState<_AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends ConsumerState<_AppWithSplash> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _initialized = false;
      _error = null;
    });

    BalanceMigrationResult migration = const BalanceMigrationResult();
    try {
      await HiveStorage.init();
      // Strictly before the first reconcile: the chain rebuild would otherwise
      // zero the earliest month's carry-over, leaving nothing to seed from.
      migration = await BalanceMigration.runIfNeeded();
      await ExpenseRepository().reconcileMonthlyExpenses();
      await SharedPreferences.getInstance();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Storage error: $e');
      return;
    }
    if (!mounted) return;

    if (migration.migrated) {
      ref.read(migrationNoticeProvider.notifier).state =
          migration.backupError == null
              ? 'Balances recalculated. A backup was saved inside the app.'
              : 'Balances recalculated, but the automatic backup could not be saved.';
    }
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text('Failed to initialize',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _init,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading...',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }

    return const ExpenseTrackerApp();
  }
}
