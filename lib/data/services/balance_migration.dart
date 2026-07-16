import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/hive_storage.dart';
import 'data_export_import.dart';

/// Result of the one-time balance migration, surfaced to the user so a
/// restated history doesn't look like corruption.
class BalanceMigrationResult {
  final bool migrated;
  final String? backupPath;
  final Object? backupError;

  const BalanceMigrationResult({
    this.migrated = false,
    this.backupPath,
    this.backupError,
  });
}

/// Prepares stored balances for the carry-over chain.
///
/// Before the chain existed, `carryOver` was a frozen snapshot written once when
/// a month was first opened. The chain now derives it as
/// `previousRemaining + carryOverAdjustment`, which means the *earliest* month —
/// which has no predecessor — would rebuild to just its adjustment, defaulting
/// to zero and silently discarding the user's opening balance.
///
/// This seeds that opening balance into the adjustment so it survives, and takes
/// a JSON backup to app-private storage first because every later month's stored
/// figure is about to be recalculated.
///
/// **Must run before the first [ExpenseRepository.reconcileMonthlyExpenses] of
/// the process**: once the chain has zeroed the earliest month's `carryOver`,
/// there is nothing left to seed from.
class BalanceMigration {
  static const _flagKey = 'balances_migrated_v2';

  static Future<BalanceMigrationResult> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flagKey) == true) {
      return const BalanceMigrationResult();
    }

    final box = HiveStorage.monthlyBalanceBoxRef;
    if (box.isEmpty) {
      // Nothing to restate; a fresh install needs no backup or notice.
      await prefs.setBool(_flagKey, true);
      return const BalanceMigrationResult();
    }

    String? backupPath;
    Object? backupError;
    try {
      backupPath = await ExportImportData.exportBackupToAppStorage();
    } catch (e) {
      // A failed backup must not block the seed below: leaving the earliest
      // month unseeded would lose its opening balance permanently on the very
      // next reconcile. Report it instead.
      backupError = e;
    }

    final balances = box.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final earliest = balances.first;
    if (earliest.carryOverAdjustment == 0 && earliest.carryOver != 0) {
      earliest.carryOverAdjustment = earliest.carryOver;
      await earliest.save();
    }

    await prefs.setBool(_flagKey, true);
    return BalanceMigrationResult(
      migrated: true,
      backupPath: backupPath,
      backupError: backupError,
    );
  }
}
