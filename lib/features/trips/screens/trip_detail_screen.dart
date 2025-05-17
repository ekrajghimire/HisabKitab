import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_model.dart';
import '../../../models/expense_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../expenses/providers/expenses_provider.dart';

class TripDetailScreen extends StatefulWidget {
  final TripModel trip;

  const TripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  _TripDetailScreenState createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ExpenseModel> _expenses = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final expensesProvider = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    );

    _userId = authProvider.user?.uid;
    await expensesProvider.fetchGroupExpenses(widget.trip.groupId);

    setState(() {
      _expenses = expensesProvider.getGroupExpenses(widget.trip.groupId);
      _isLoading = false;
    });
  }

  double get _myExpensesTotal {
    if (_userId == null) return 0;
    return _expenses
        .where((expense) => expense.paidById == _userId)
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  double get _totalExpenses {
    return _expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  Map<DateTime, List<ExpenseModel>> get _groupedExpenses {
    final grouped = <DateTime, List<ExpenseModel>>{};

    for (final expense in _expenses) {
      // Get date without time
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(expense);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.trip.name),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Balances'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Expense totals
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Expenses',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '₹${_myExpensesTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Expenses',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '₹${_totalExpenses.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Expenses tab
                        _buildExpensesTab(),

                        // Balances tab
                        Center(
                          child: Text(
                            'Balances Coming Soon',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add expense screen
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildExpensesTab() {
    final groupedExpenses = _groupedExpenses;
    final sortedDates =
        groupedExpenses.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // Sort by most recent

    if (groupedExpenses.isEmpty) {
      return const Center(
        child: Text(
          'No expenses yet. Add your first expense!',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final expenses = groupedExpenses[date]!;
        final isToday = _isToday(date);
        final isYesterday = _isYesterday(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                isToday
                    ? 'Today'
                    : isYesterday
                    ? 'Yesterday'
                    : DateFormat('MMMM d, y').format(date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            ...expenses.map((expense) => _buildExpenseItem(expense)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense) {
    // Find the emoji for the category
    String emoji = '💰'; // Default
    if (expense.category != null) {
      switch (expense.category) {
        case 'Food':
          emoji = '🍔';
          break;
        case 'Drinks':
          emoji = '🥂';
          break;
        case 'Transportation':
          emoji = '🚕';
          break;
        case 'Accommodation':
          emoji = '🏨';
          break;
        case 'Activities':
          emoji = '🏄‍♂️';
          break;
        case 'Shopping':
          emoji = '🛍️';
          break;
        case 'Code':
          emoji = '💻';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          'Paid by ${expense.paidById == _userId ? 'Me (me)' : 'Others'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
        trailing: Text(
          '₹${expense.amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        onTap: () {
          // TODO: Navigate to expense details
        },
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
