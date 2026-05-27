import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/split_participant_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/split_provider.dart';
import '../../providers/payer_name_provider.dart';
import 'widgets/expense_form.dart';
import 'widgets/participant_entry.dart';

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
  late TextEditingController _creditCardNameController;
  late DateTime _selectedDate;
  late String _selectedCategoryId;
  late String _paymentMethod;
  bool _isSplit = false;
  String _splitMethod = 'equal';
  final List<ParticipantEntry> _participants = [];
  bool _isSlipPerson = true;
  List<int> _remainderAllocations = [];

  bool get _isEditing => widget.expense != null;

  String _generateId() => _uuid.v4();

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense?.name ?? '');
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _creditCardNameController = TextEditingController(
      text: widget.expense?.creditCardName ?? '',
    );
    _selectedDate = widget.expense?.date ?? DateTime.now();
    _selectedCategoryId = widget.expense?.categoryId ?? 'food';
    _paymentMethod = widget.expense?.paymentMethod ?? 'cash';

    // Load existing split data when editing
    if (widget.expense != null) {
      final existingSplit = ref.read(splitProvider.notifier).getSplitByExpenseId(widget.expense!.id);
      if (existingSplit != null) {
        _isSplit = true;
        _splitMethod = existingSplit.splitMethod;
        _isSlipPerson = existingSplit.slipPersonId != null;
        final storedParticipants = ref.read(splitProvider.notifier).getParticipantsBySplitId(existingSplit.id);
        for (final p in storedParticipants) {
          _participants.add(ParticipantEntry(
            nameController: TextEditingController(text: p.name),
            amountController: TextEditingController(text: p.amount.toStringAsFixed(2)),
            amount: p.amount,
            isSlipPayer: p.isSlipPayer,
            isPaid: p.isPaid,
          ));
        }
        // Preserve stored amounts; reconstruct remainder allocations for display
        if (_splitMethod == 'equal' && _participants.isNotEmpty) {
          final amt = double.tryParse(_amountController.text) ?? 0;
          final totalCents = (amt * 100).round();
          final baseCents = totalCents ~/ _participants.length;
          _remainderAllocations = _participants.map((p) {
            return ((p.amount * 100).round()) - baseCents;
          }).toList();
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _creditCardNameController.dispose();
    for (final p in _participants) {
      p.nameController.dispose();
      p.amountController.dispose();
    }
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

  void _addParticipant() {
    final payerName = ref.read(payerNameProvider);
    setState(() {
      _participants.add(ParticipantEntry(
        nameController: TextEditingController(
          text: _participants.isEmpty ? payerName : '',
        ),
      ));
      _updateSplitAmounts();
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants[index].nameController.dispose();
      _participants[index].amountController.dispose();
      _participants.removeAt(index);
      _updateSplitAmounts();
    });
  }

  // ── Feature 2: Remainder Distribution ──
  void _updateSplitAmounts() {
    if (_splitMethod != 'equal' || _participants.isEmpty) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final count = _participants.length;
    if (count == 0 || amount <= 0) return;

    // Calculate in cents to avoid floating point errors
    final totalCents = (amount * 100).round();
    final baseCents = totalCents ~/ count;
    final remainder = totalCents % count;
    final baseAmount = baseCents / 100;

    for (final p in _participants) {
      p.amount = baseAmount;
      p.remainderCents = 0;
      p.amountController.text = baseAmount.toStringAsFixed(2);
    }

    _remainderAllocations = List.filled(count, 0);

    // Auto-assign remainder to first participants if no user allocation yet
    if (remainder > 0 && _remainderAllocations.every((r) => r == 0)) {
      for (int i = 0; i < remainder; i++) {
        _remainderAllocations[i % count] += 1;
      }
    }

    _applyRemainderAllocations();
  }

  void _applyRemainderAllocations() {
    if (_splitMethod != 'equal' || _participants.isEmpty) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final totalCents = (amount * 100).round();
    final baseCents = totalCents ~/ _participants.length;

    for (int i = 0; i < _participants.length; i++) {
      final p = _participants[i];
      final finalCents = baseCents + (_remainderAllocations.length > i ? _remainderAllocations[i] : 0);
      p.amount = finalCents / 100;
      p.remainderCents = _remainderAllocations.length > i ? _remainderAllocations[i] : 0;
      p.amountController.text = (finalCents / 100).toStringAsFixed(2);
    }
  }

  void _toggleRemainderAllocation(int participantIndex, int delta) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final totalCents = (amount * 100).round();
    final remainder = totalCents % _participants.length;

    final newVal = (_remainderAllocations[participantIndex] + delta).clamp(0, remainder);

    if (newVal == _remainderAllocations[participantIndex]) return;

    setState(() {
      _remainderAllocations[participantIndex] = newVal;

      // Rebalance - ensure total remainder allocations match remainder
      final currentSum = _remainderAllocations.fold(0, (a, b) => a + b);
      int diff = remainder - currentSum;

      if (diff > 0) {
        for (int i = 0; i < _participants.length && diff > 0; i++) {
          if (i == participantIndex) continue;
          _remainderAllocations[i] += 1;
          diff -= 1;
        }
      } else if (diff < 0) {
        for (int i = 0; i < _participants.length && diff < 0; i++) {
          if (i == participantIndex) continue;
          final canRemove = _remainderAllocations[i].clamp(0, -diff);
          _remainderAllocations[i] -= canRemove;
          diff += canRemove;
        }
      }

      _applyRemainderAllocations();
    });
  }

  void _onAmountChanged() {
    if (_splitMethod == 'equal') {
      _updateSplitAmounts();
    }
  }

  // ── Feature 3: Slip Person ──
  void _toggleSlipPerson(bool value) {
    setState(() {
      _isSlipPerson = value;
      if (value && _participants.isNotEmpty && _participants.length > 1) {
        // Don't add a duplicate slip person - the first participant represents the user
      }
    });
  }

  double _calculateTotalSplitAmount() {
    return _participants.fold<double>(0, (sum, p) => sum + p.amount);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSplit && _participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one participant'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // ── Validate split totals match ──
    if (_isSplit) {
      final total = double.tryParse(_amountController.text) ?? 0;
      final splitTotal = _calculateTotalSplitAmount();
      if ((splitTotal - total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split total (₹${splitTotal.toStringAsFixed(2)}) must equal expense amount (₹${total.toStringAsFixed(2)})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final expense = ExpenseModel(
      id: widget.expense?.id ?? '',
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
      paymentMethod: _paymentMethod,
      creditCardName: _paymentMethod == 'credit_card' ? _creditCardNameController.text.trim() : null,
      repaymentStatus: _paymentMethod == 'credit_card' ? 'pending' : 'none',
    );

    // ── Build participants list with slip person ──
    List<SplitParticipantModel> splitParticipants;
    if (_isSplit) {
      splitParticipants = _participants.asMap().entries.map((entry) {
        final index = entry.key;
        final p = entry.value;
        return SplitParticipantModel(
          id: index == 0 && _isSlipPerson ? _generateId() : '',
          splitId: '',
          name: p.nameController.text.trim(),
          amount: _splitMethod == 'equal' ? p.amount : (double.tryParse(p.amountController.text) ?? 0),
          isSlipPayer: index == 0 && _isSlipPerson,
          isPaid: p.isPaid,
        );
      }).toList();

      if (_isEditing) {
        await ref.read(expensesProvider.notifier).updateExpense(expense);
        await ref.read(splitProvider.notifier).deleteSplitByExpenseId(expense.id);
        await ref.read(splitProvider.notifier).createSplit(
          expenseId: expense.id,
          totalAmount: expense.amount,
          participants: splitParticipants,
          splitMethod: _splitMethod,
        );
      } else {
        final expenseId = await ref.read(expensesProvider.notifier).addExpense(expense);
        await ref.read(splitProvider.notifier).createSplit(
          expenseId: expenseId,
          totalAmount: expense.amount,
          participants: splitParticipants,
          splitMethod: _splitMethod,
        );
      }
    } else {
      if (_isEditing) {
        await ref.read(expensesProvider.notifier).updateExpense(expense);
        await ref.read(splitProvider.notifier).deleteSplitByExpenseId(expense.id);
      } else {
        await ref.read(expensesProvider.notifier).addExpense(expense);
      }
    }

    ref.read(balanceProvider.notifier).loadBalance();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Expense updated' : 'Expense added'),
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
        creditCardNameController: _creditCardNameController,
        paymentMethod: _paymentMethod,
        selectedDate: _selectedDate,
        selectedCategoryId: _selectedCategoryId,
        isEditing: _isEditing,
        onDateSelected: _selectDate,
        onPaymentMethodChanged: (method) {
          setState(() {
            _paymentMethod = method;
          });
        },
        onCategoryChanged: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId;
          });
        },
        onSave: _saveExpense,
        isSplit: _isSplit,
        splitMethod: _splitMethod,
        participants: _participants,
        onSplitToggled: (value) {
          setState(() {
            _isSplit = value;
            if (value) {
              _isSlipPerson = true;
              _updateSplitAmounts();
            }
          });
        },
        onSplitMethodChanged: (method) {
          setState(() {
            _splitMethod = method;
            _updateSplitAmounts();
          });
        },
        onAddParticipant: _addParticipant,
        onRemoveParticipant: _removeParticipant,
        onAmountChanged: _onAmountChanged,
        isSlipPerson: _isSlipPerson,
        onSlipPersonToggled: _toggleSlipPerson,
        remainderAllocations: _remainderAllocations,
        onRemainderToggle: _toggleRemainderAllocation,
      ),
    );
  }
}
