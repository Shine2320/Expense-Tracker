import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../models/monthly_balance_model.dart';
import '../models/expense_split_model.dart';
import '../models/split_participant_model.dart';
import '../datasources/hive_storage.dart';
import '../repositories/expense_repository.dart';

class ExportImportData {
  static const MethodChannel _downloadsChannel = MethodChannel(
    'expense_tracker/downloads',
  );

  static Box<ExpenseModel> get _expenseBox => HiveStorage.expensesBoxRef;
  static Box<CategoryModel> get _categoryBox => HiveStorage.categoriesBoxRef;
  static Box<MonthlyBalanceModel> get _balanceBox =>
      HiveStorage.monthlyBalanceBoxRef;
  static Box<ExpenseSplitModel> get _splitBox =>
      HiveStorage.expenseSplitsBoxRef;
  static Box<SplitParticipantModel> get _participantBox =>
      HiveStorage.splitParticipantsBoxRef;

  // ── Serialize all data to a JSON map ──
  static Map<String, dynamic> _serializeAll() {
    return {
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'expenses': _expenseBox.values.map(_expenseToExportMap).toList(),
      'categories': _categoryBox.values.map((c) => c.toMap()).toList(),
      'monthlyBalances': _balanceBox.values.map((b) => b.toMap()).toList(),
      'expenseSplits': _splitBox.values.map(_splitToExportMap).toList(),
      'splitParticipants':
          _participantBox.values.map(_participantToExportMap).toList(),
    };
  }

  static Map<String, dynamic> _expenseToExportMap(ExpenseModel expense) {
    return {
      ...expense.toMap(),
      'date': expense.date.toIso8601String(),
      'createdAt': expense.createdAt.toIso8601String(),
      'repaymentDate': expense.repaymentDate?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _splitToExportMap(ExpenseSplitModel split) {
    return {
      ...split.toMap(),
      'createdAt': split.createdAt.toIso8601String(),
    };
  }

  static Map<String, dynamic> _participantToExportMap(
    SplitParticipantModel participant,
  ) {
    return {
      ...participant.toMap(),
      'paidAt': participant.paidAt?.toIso8601String(),
    };
  }

  // ── Deserialize from JSON map (import) ──
  static Future<void> _deserializeAll(Map<String, dynamic> data) async {
    // Expenses
    if (data['expenses'] is List) {
      final importedIds = <String>{};
      for (final item in data['expenses'] as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        importedIds.add(id);
        await _expenseBox.put(
          id,
          ExpenseModel.fromMap({
            ...map,
            'id': id,
            'amount': _toDouble(map['amount']),
            'date': _toDateTime(map['date']),
            'createdAt': _toDateTime(map['createdAt']),
            'repaymentDate': _toNullableDateTime(map['repaymentDate']),
          }),
        );
      }
      await _deleteMissingKeys(_expenseBox, importedIds);
    }
    // Categories
    if (data['categories'] is List) {
      final importedIds = <String>{};
      for (final item in data['categories'] as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        importedIds.add(id);
        await _categoryBox.put(
          id,
          CategoryModel.fromMap({
            ...map,
            'id': id,
          }),
        );
      }
      await _deleteMissingKeys(_categoryBox, importedIds);
    }
    // Monthly balances
    if (data['monthlyBalances'] is List) {
      final importedIds = <String>{};
      for (final item in data['monthlyBalances'] as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        importedIds.add(id);
        await _balanceBox.put(
          id,
          MonthlyBalanceModel.fromMap({
            ...map,
            'id': id,
            'salary': _toDouble(map['salary']),
            'carryOver': _toDouble(map['carryOver']),
            'totalExpenses': _toDouble(map['totalExpenses']),
          }),
        );
      }
      await _deleteMissingKeys(_balanceBox, importedIds);
    }
    // Expense splits
    if (data['expenseSplits'] is List) {
      final importedIds = <String>{};
      for (final item in data['expenseSplits'] as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        importedIds.add(id);
        await _splitBox.put(
          id,
          ExpenseSplitModel.fromMap({
            ...map,
            'id': id,
            'totalAmount': _toDouble(map['totalAmount']),
            'createdAt': _toDateTime(map['createdAt']),
          }),
        );
      }
      await _deleteMissingKeys(_splitBox, importedIds);
    }
    // Split participants
    if (data['splitParticipants'] is List) {
      final importedIds = <String>{};
      for (final item in data['splitParticipants'] as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        importedIds.add(id);
        await _participantBox.put(
          id,
          SplitParticipantModel.fromMap({
            ...map,
            'id': id,
            'amount': _toDouble(map['amount']),
            'paidAt': _toNullableDateTime(map['paidAt']),
          }),
        );
      }
      await _deleteMissingKeys(_participantBox, importedIds);
    }
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Future<void> _deleteMissingKeys<T>(
    Box<T> box,
    Set<String> importedIds,
  ) async {
    final keysToDelete =
        box.keys.where((key) => !importedIds.contains(key.toString())).toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }

  static Future<String> _saveToDownloads({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (Platform.isAndroid) {
      final path = await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        {
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': Uint8List.fromList(bytes),
        },
      );
      return path ?? 'Downloads/$fileName';
    }

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ── Export to JSON file ──
  static Future<String> exportToJson() async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_serializeAll());
    final fileName =
        'expense_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    return _saveToDownloads(
      fileName: fileName,
      bytes: utf8.encode(jsonStr),
      mimeType: 'application/json',
    );
  }

  // ── Import from JSON file ──
  static Future<void> importFromJson(String filePath) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await _deserializeAll(data);
    await ExpenseRepository().reconcileMonthlyExpenses();
  }

  // ── Export to Excel file ──
  static Future<String> exportToExcel() async {
    final excel = Excel.createExcel();
    final allData = _serializeAll();

    // Expenses sheet
    final expenseSheet = excel['Expenses'];
    expenseSheet.appendRow([
      'ID',
      'Name',
      'Amount',
      'Date',
      'CategoryID',
      'CreatedAt',
      'PaymentMethod',
      'CreditCardName',
      'RepaymentStatus',
      'RepaymentDate',
      'IsDeleted'
    ]);
    for (final e in allData['expenses'] as List) {
      expenseSheet.appendRow([
        e['id'],
        e['name'],
        e['amount'],
        e['date']?.toString(),
        e['categoryId'],
        e['createdAt']?.toString(),
        e['paymentMethod'],
        e['creditCardName'],
        e['repaymentStatus'],
        e['repaymentDate']?.toString(),
        e['isDeleted'],
      ]);
    }

    // Categories sheet
    final catSheet = excel['Categories'];
    catSheet.appendRow(['ID', 'Name', 'Emoji', 'IsCustom']);
    for (final c in allData['categories'] as List) {
      catSheet.appendRow([c['id'], c['name'], c['emoji'], c['isCustom']]);
    }

    // Monthly Balances sheet
    final balSheet = excel['MonthlyBalances'];
    balSheet.appendRow(['ID', 'Salary', 'CarryOver', 'TotalExpenses']);
    for (final b in allData['monthlyBalances'] as List) {
      balSheet.appendRow(
          [b['id'], b['salary'], b['carryOver'], b['totalExpenses']]);
    }

    // Expense Splits sheet
    final splitSheet = excel['ExpenseSplits'];
    splitSheet.appendRow([
      'ID',
      'ExpenseID',
      'TotalAmount',
      'CreatedAt',
      'SplitMethod',
      'SlipPersonID'
    ]);
    for (final s in allData['expenseSplits'] as List) {
      splitSheet.appendRow([
        s['id'],
        s['expenseId'],
        s['totalAmount'],
        s['createdAt']?.toString(),
        s['splitMethod'],
        s['slipPersonId'],
      ]);
    }

    // Split Participants sheet
    final partSheet = excel['SplitParticipants'];
    partSheet.appendRow(
        ['ID', 'SplitID', 'Name', 'Amount', 'IsPaid', 'PaidAt', 'IsSlipPayer']);
    for (final p in allData['splitParticipants'] as List) {
      partSheet.appendRow([
        p['id'],
        p['splitId'],
        p['name'],
        p['amount'],
        p['isPaid'],
        p['paidAt']?.toString(),
        p['isSlipPayer'],
      ]);
    }

    final fileName =
        'expense_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to save Excel file');
    return _saveToDownloads(
      fileName: fileName,
      bytes: fileBytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ── Import from Excel file ──
  static Future<void> importFromExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Expenses sheet
    final expenseSheet = excel.tables['Expenses'];
    if (expenseSheet != null) {
      final importedIds = <String>{};
      for (int i = 1; i < expenseSheet.rows.length; i++) {
        final row = expenseSheet.rows[i];
        if (row.length < 11) continue;
        final id = row[0]?.value?.toString() ?? '';
        if (id.isEmpty) continue;
        importedIds.add(id);
        await _expenseBox.put(
          id,
          ExpenseModel.fromMap({
            'id': id,
            'name': row[1]?.value?.toString() ?? '',
            'amount': double.tryParse(row[2]?.value?.toString() ?? '') ?? 0,
            'date': DateTime.tryParse(row[3]?.value?.toString() ?? '') ??
                DateTime.now(),
            'categoryId': row[4]?.value?.toString() ?? '',
            'createdAt': DateTime.tryParse(row[5]?.value?.toString() ?? '') ??
                DateTime.now(),
            'paymentMethod': row[6]?.value?.toString() ?? 'cash',
            'creditCardName': row[7]?.value?.toString(),
            'repaymentStatus': row[8]?.value?.toString() ?? 'none',
            'repaymentDate': row[9]?.value != null
                ? DateTime.tryParse(row[9]!.value.toString())
                : null,
            'isDeleted': row[10]?.value?.toString() == 'true',
          }),
        );
      }
      await _deleteMissingKeys(_expenseBox, importedIds);
    }

    // Categories sheet
    final catSheet = excel.tables['Categories'];
    if (catSheet != null) {
      final importedIds = <String>{};
      for (int i = 1; i < catSheet.rows.length; i++) {
        final row = catSheet.rows[i];
        if (row.length < 4) continue;
        final id = row[0]?.value?.toString() ?? '';
        if (id.isEmpty) continue;
        importedIds.add(id);
        await _categoryBox.put(
          id,
          CategoryModel.fromMap({
            'id': id,
            'name': row[1]?.value?.toString() ?? '',
            'emoji': row[2]?.value?.toString() ?? '📦',
            'isCustom': row[3]?.value?.toString() == 'true',
          }),
        );
      }
      await _deleteMissingKeys(_categoryBox, importedIds);
    }

    // Monthly Balances sheet
    final balSheet = excel.tables['MonthlyBalances'];
    if (balSheet != null) {
      final importedIds = <String>{};
      for (int i = 1; i < balSheet.rows.length; i++) {
        final row = balSheet.rows[i];
        if (row.length < 4) continue;
        final id = row[0]?.value?.toString() ?? '';
        if (id.isEmpty) continue;
        importedIds.add(id);
        await _balanceBox.put(
          id,
          MonthlyBalanceModel.fromMap({
            'id': id,
            'salary': double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0,
            'carryOver': double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0,
            'totalExpenses':
                double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0,
          }),
        );
      }
      await _deleteMissingKeys(_balanceBox, importedIds);
    }

    // Expense Splits sheet
    final splitSheet = excel.tables['ExpenseSplits'];
    if (splitSheet != null) {
      final importedIds = <String>{};
      for (int i = 1; i < splitSheet.rows.length; i++) {
        final row = splitSheet.rows[i];
        if (row.length < 6) continue;
        final id = row[0]?.value?.toString() ?? '';
        if (id.isEmpty) continue;
        importedIds.add(id);
        await _splitBox.put(
          id,
          ExpenseSplitModel.fromMap({
            'id': id,
            'expenseId': row[1]?.value?.toString() ?? '',
            'totalAmount':
                double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0,
            'createdAt': DateTime.tryParse(row[3]?.value?.toString() ?? '') ??
                DateTime.now(),
            'splitMethod': row[4]?.value?.toString() ?? 'equal',
            'slipPersonId': row[5]?.value?.toString(),
          }),
        );
      }
      await _deleteMissingKeys(_splitBox, importedIds);
    }

    // Split Participants sheet
    final partSheet = excel.tables['SplitParticipants'];
    if (partSheet != null) {
      final importedIds = <String>{};
      for (int i = 1; i < partSheet.rows.length; i++) {
        final row = partSheet.rows[i];
        if (row.length < 7) continue;
        final id = row[0]?.value?.toString() ?? '';
        if (id.isEmpty) continue;
        importedIds.add(id);
        await _participantBox.put(
          id,
          SplitParticipantModel.fromMap({
            'id': id,
            'splitId': row[1]?.value?.toString() ?? '',
            'name': row[2]?.value?.toString() ?? '',
            'amount': double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0,
            'isPaid': row[4]?.value?.toString() == 'true',
            'paidAt': row[5]?.value != null
                ? DateTime.tryParse(row[5]!.value.toString())
                : null,
            'isSlipPayer': row[6]?.value?.toString() == 'true',
          }),
        );
      }
      await _deleteMissingKeys(_participantBox, importedIds);
    }

    await ExpenseRepository().reconcileMonthlyExpenses();
  }

  // ── Pick a file for import ──
  static Future<String?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }
}
