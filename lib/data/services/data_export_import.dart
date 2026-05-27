import 'dart:convert';
import 'dart:io';
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

class ExportImportData {
  static Box<ExpenseModel> get _expenseBox => HiveStorage.expensesBoxRef;
  static Box<CategoryModel> get _categoryBox => HiveStorage.categoriesBoxRef;
  static Box<MonthlyBalanceModel> get _balanceBox => HiveStorage.monthlyBalanceBoxRef;
  static Box<ExpenseSplitModel> get _splitBox => HiveStorage.expenseSplitsBoxRef;
  static Box<SplitParticipantModel> get _participantBox => HiveStorage.splitParticipantsBoxRef;

  // ── Serialize all data to a JSON map ──
  static Map<String, dynamic> _serializeAll() {
    return {
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'expenses': _expenseBox.values.map((e) => e.toMap()).toList(),
      'categories': _categoryBox.values.map((c) => c.toMap()).toList(),
      'monthlyBalances': _balanceBox.values.map((b) => b.toMap()).toList(),
      'expenseSplits': _splitBox.values.map((s) => s.toMap()).toList(),
      'splitParticipants': _participantBox.values.map((p) => p.toMap()).toList(),
    };
  }

  // ── Deserialize from JSON map (import) ──
  static void _deserializeAll(Map<String, dynamic> data) {
    // Expenses
    if (data['expenses'] is List) {
      _expenseBox.clear();
      for (final item in data['expenses'] as List) {
        _expenseBox.put(
          item['id'] as String,
          ExpenseModel.fromMap(item as Map<String, dynamic>),
        );
      }
    }
    // Categories
    if (data['categories'] is List) {
      _categoryBox.clear();
      for (final item in data['categories'] as List) {
        _categoryBox.put(
          item['id'] as String,
          CategoryModel.fromMap(item as Map<String, dynamic>),
        );
      }
    }
    // Monthly balances
    if (data['monthlyBalances'] is List) {
      _balanceBox.clear();
      for (final item in data['monthlyBalances'] as List) {
        _balanceBox.put(
          item['id'] as String,
          MonthlyBalanceModel.fromMap(item as Map<String, dynamic>),
        );
      }
    }
    // Expense splits
    if (data['expenseSplits'] is List) {
      _splitBox.clear();
      for (final item in data['expenseSplits'] as List) {
        _splitBox.put(
          item['id'] as String,
          ExpenseSplitModel.fromMap(item as Map<String, dynamic>),
        );
      }
    }
    // Split participants
    if (data['splitParticipants'] is List) {
      _participantBox.clear();
      for (final item in data['splitParticipants'] as List) {
        _participantBox.put(
          item['id'] as String,
          SplitParticipantModel.fromMap(item as Map<String, dynamic>),
        );
      }
    }
  }

  // ── Export to JSON file ──
  static Future<String> exportToJson() async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_serializeAll());
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'expense_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  // ── Import from JSON file ──
  static Future<void> importFromJson(String filePath) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    _deserializeAll(data);
  }

  // ── Export to Excel file ──
  static Future<String> exportToExcel() async {
    final excel = Excel.createExcel();
    final allData = _serializeAll();

    // Expenses sheet
    final expenseSheet = excel['Expenses'];
    expenseSheet.appendRow([
      'ID', 'Name', 'Amount', 'Date', 'CategoryID', 'CreatedAt',
      'PaymentMethod', 'CreditCardName', 'RepaymentStatus', 'RepaymentDate', 'IsDeleted'
    ]);
    for (final e in allData['expenses'] as List) {
      expenseSheet.appendRow([
        e['id'], e['name'], e['amount'], e['date']?.toString(), e['categoryId'],
        e['createdAt']?.toString(), e['paymentMethod'], e['creditCardName'],
        e['repaymentStatus'], e['repaymentDate']?.toString(), e['isDeleted'],
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
      balSheet.appendRow([b['id'], b['salary'], b['carryOver'], b['totalExpenses']]);
    }

    // Expense Splits sheet
    final splitSheet = excel['ExpenseSplits'];
    splitSheet.appendRow(['ID', 'ExpenseID', 'TotalAmount', 'CreatedAt', 'SplitMethod', 'SlipPersonID']);
    for (final s in allData['expenseSplits'] as List) {
      splitSheet.appendRow([
        s['id'], s['expenseId'], s['totalAmount'], s['createdAt']?.toString(),
        s['splitMethod'], s['slipPersonId'],
      ]);
    }

    // Split Participants sheet
    final partSheet = excel['SplitParticipants'];
    partSheet.appendRow(['ID', 'SplitID', 'Name', 'Amount', 'IsPaid', 'PaidAt', 'IsSlipPayer']);
    for (final p in allData['splitParticipants'] as List) {
      partSheet.appendRow([
        p['id'], p['splitId'], p['name'], p['amount'], p['isPaid'],
        p['paidAt']?.toString(), p['isSlipPayer'],
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'expense_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to save Excel file');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes);
    return file.path;
  }

  // ── Import from Excel file ──
  static Future<void> importFromExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Expenses sheet
    final expenseSheet = excel['Expenses'];
    if (expenseSheet != null && expenseSheet.rows.length > 1) {
      _expenseBox.clear();
      for (int i = 1; i < expenseSheet.rows.length; i++) {
        final row = expenseSheet.rows[i];
        if (row.length < 11) continue;
        _expenseBox.put(
          row[0]?.value?.toString() ?? '',
          ExpenseModel.fromMap({
            'id': row[0]?.value?.toString() ?? '',
            'name': row[1]?.value?.toString() ?? '',
            'amount': double.tryParse(row[2]?.value?.toString() ?? '') ?? 0,
            'date': DateTime.tryParse(row[3]?.value?.toString() ?? '') ?? DateTime.now(),
            'categoryId': row[4]?.value?.toString() ?? '',
            'createdAt': DateTime.tryParse(row[5]?.value?.toString() ?? '') ?? DateTime.now(),
            'paymentMethod': row[6]?.value?.toString() ?? 'cash',
            'creditCardName': row[7]?.value?.toString(),
            'repaymentStatus': row[8]?.value?.toString() ?? 'none',
            'repaymentDate': row[9]?.value != null ? DateTime.tryParse(row[9]!.value.toString()) : null,
            'isDeleted': row[10]?.value?.toString() == 'true',
          }),
        );
      }
    }

    // Categories sheet
    final catSheet = excel['Categories'];
    if (catSheet != null && catSheet.rows.length > 1) {
      _categoryBox.clear();
      for (int i = 1; i < catSheet.rows.length; i++) {
        final row = catSheet.rows[i];
        if (row.length < 4) continue;
        _categoryBox.put(
          row[0]?.value?.toString() ?? '',
          CategoryModel.fromMap({
            'id': row[0]?.value?.toString() ?? '',
            'name': row[1]?.value?.toString() ?? '',
            'emoji': row[2]?.value?.toString() ?? '📦',
            'isCustom': row[3]?.value?.toString() == 'true',
          }),
        );
      }
    }

    // Monthly Balances sheet
    final balSheet = excel['MonthlyBalances'];
    if (balSheet != null && balSheet.rows.length > 1) {
      _balanceBox.clear();
      for (int i = 1; i < balSheet.rows.length; i++) {
        final row = balSheet.rows[i];
        if (row.length < 4) continue;
        _balanceBox.put(
          row[0]?.value?.toString() ?? '',
          MonthlyBalanceModel.fromMap({
            'id': row[0]?.value?.toString() ?? '',
            'salary': double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0,
            'carryOver': double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0,
            'totalExpenses': double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0,
          }),
        );
      }
    }

    // Expense Splits sheet
    final splitSheet = excel['ExpenseSplits'];
    if (splitSheet != null && splitSheet.rows.length > 1) {
      _splitBox.clear();
      for (int i = 1; i < splitSheet.rows.length; i++) {
        final row = splitSheet.rows[i];
        if (row.length < 6) continue;
        _splitBox.put(
          row[0]?.value?.toString() ?? '',
          ExpenseSplitModel.fromMap({
            'id': row[0]?.value?.toString() ?? '',
            'expenseId': row[1]?.value?.toString() ?? '',
            'totalAmount': double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0,
            'createdAt': DateTime.tryParse(row[3]?.value?.toString() ?? '') ?? DateTime.now(),
            'splitMethod': row[4]?.value?.toString() ?? 'equal',
            'slipPersonId': row[5]?.value?.toString(),
          }),
        );
      }
    }

    // Split Participants sheet
    final partSheet = excel['SplitParticipants'];
    if (partSheet != null && partSheet.rows.length > 1) {
      _participantBox.clear();
      for (int i = 1; i < partSheet.rows.length; i++) {
        final row = partSheet.rows[i];
        if (row.length < 7) continue;
        _participantBox.put(
          row[0]?.value?.toString() ?? '',
          SplitParticipantModel.fromMap({
            'id': row[0]?.value?.toString() ?? '',
            'splitId': row[1]?.value?.toString() ?? '',
            'name': row[2]?.value?.toString() ?? '',
            'amount': double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0,
            'isPaid': row[4]?.value?.toString() == 'true',
            'paidAt': row[5]?.value != null ? DateTime.tryParse(row[5]!.value.toString()) : null,
            'isSlipPayer': row[6]?.value?.toString() == 'true',
          }),
        );
      }
    }
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
