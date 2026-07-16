import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/services/data_export_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Guard on untrusted workbooks.
///
/// `Excel.decodeBytes` inflates every entry with no ceiling, on the calling
/// isolate. A small file whose sheet XML expands to gigabytes freezes the UI and
/// gets the process OOM-killed — which the import's try/catch cannot recover
/// from, because a Dart OOM kills the process rather than throwing. The guard
/// has to reject such a file from its declared entry sizes, before inflating.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  final defaultCap = ExportImportData.maxUncompressedBytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_guard_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExpenseModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MonthlyBalanceModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ExpenseSplitModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(SplitParticipantModelAdapter());
    }
    await Hive.openBox<ExpenseModel>(HiveStorage.expensesBox);
    await Hive.openBox<CategoryModel>(HiveStorage.categoriesBox);
    await Hive.openBox<MonthlyBalanceModel>(HiveStorage.monthlyBalanceBox);
    await Hive.openBox<ExpenseSplitModel>(HiveStorage.expenseSplitsBox);
    await Hive.openBox<SplitParticipantModel>(HiveStorage.splitParticipantsBox);
  });

  tearDown(() async {
    ExportImportData.maxUncompressedBytes = defaultCap;
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<String> writeFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('a workbook claiming more than the cap is rejected before inflating',
      () async {
    // A zip of highly compressible zeros: tiny on disk, large once inflated —
    // the shape of a zip bomb, scaled down so the test itself stays cheap. The
    // cap is lowered to meet it rather than allocating a real one.
    ExportImportData.maxUncompressedBytes = 64 * 1024;
    final archive = Archive()
      ..addFile(ArchiveFile('xl/worksheets/sheet1.xml', 1024 * 1024,
          List.filled(1024 * 1024, 0)));
    final bytes = ZipEncoder().encode(archive)!;

    expect(bytes.length, lessThan(64 * 1024),
        reason: 'the compressed file must be small — that is the whole trick');

    final path = await writeFile('bomb.xlsx', bytes);

    await expectLater(
      ExportImportData.importFromExcel(path),
      throwsA(isA<ImportTooLargeException>()),
    );
  });

  test('a file that is not a zip at all is rejected as unreadable', () async {
    final path = await writeFile('notazip.xlsx', List.filled(512, 0x41));

    await expectLater(
      ExportImportData.importFromExcel(path),
      throwsA(isA<ImportTooLargeException>()),
    );
  });

  test('a real workbook under the cap passes the guard', () async {
    // Guards that reject honest files are worse than no guard: this pins that
    // the default cap does not fire on an ordinary workbook.
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];
    sheet.appendRow(['ID', 'Name']);
    sheet.appendRow(['e1', 'Groceries']);
    final path = await writeFile('real.xlsx', excel.encode()!);

    // Reaches parsing rather than tripping the guard. The header-only sheet
    // has no importable rows, so the import is a no-op over open boxes.
    await expectLater(ExportImportData.importFromExcel(path), completes);
    expect(HiveStorage.expensesBoxRef.isEmpty, isTrue);
  });
}
