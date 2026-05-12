import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/balance_provider.dart';
import 'widgets/expense_form.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  final ExpenseModel? expense;

  const AddExpenseSheet({super.key, this.expense});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  late String _selectedCategoryId;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense?.name ?? '');
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _selectedDate = widget.expense?.date ?? DateTime.now();
    _selectedCategoryId = widget.expense?.categoryId ?? 'food';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final expense = ExpenseModel(
      id: widget.expense?.id ?? '',
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
    );

    if (_isEditing) {
      ref.read(expensesProvider.notifier).updateExpense(expense);
    } else {
      ref.read(expensesProvider.notifier).addExpense(expense);
    }
    ref.read(balanceProvider.notifier).loadBalance();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Expense updated' : 'Expense added',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ExpenseForm(
        formKey: _formKey,
        nameController: _nameController,
        amountController: _amountController,
        selectedDate: _selectedDate,
        selectedCategoryId: _selectedCategoryId,
        isEditing: _isEditing,
        onDateSelected: _selectDate,
        onCategoryChanged: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId;
          });
        },
        onSave: _saveExpense,
      ),
    );
  }
}
