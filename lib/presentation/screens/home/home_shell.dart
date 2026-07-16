import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/migration_notice_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../calendar/calendar_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../add_expense/add_expense_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    CalendarScreen(),
    ExpenseListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMigrationNotice());
  }

  void _showMigrationNotice() {
    final notice = ref.read(migrationNoticeProvider);
    if (notice == null || !mounted) return;
    ref.read(migrationNoticeProvider.notifier).state = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddExpenseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Available on every tab: adding an expense is the app's primary action,
      // and it was previously unreachable from the Expenses and Calendar tabs.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addExpense),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: AppStrings.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: AppStrings.calendar,
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: AppStrings.expenses,
          ),
        ],
      ),
    );
  }
}
