import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/group_model.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/expense_model.dart';
import '../../expenses/screens/create_expense_screen.dart';
import '../../expenses/screens/expense_details_screen.dart';
import '../../../core/services/user_service.dart';

class TripDetailsScreen extends StatefulWidget {
  final GroupModel group;
  final bool autoShowExpenses;

  const TripDetailsScreen({
    required this.group,
    this.autoShowExpenses = false,
    super.key,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load expenses and go to expenses tab if requested
    _loadExpenses();

    // If coming from trip creation, automatically show a welcome message
    if (widget.autoShowExpenses) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip created! You can now start adding expenses.'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    final expensesProvider = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    );
    await expensesProvider.fetchGroupExpenses(widget.group.id);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '', // Empty title as we show the trip name in the header
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Trip icon and name
          _buildTripHeader(),

          // Tab bar
          SizedBox(
            height: 48,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Balances'),
                Tab(text: 'Photos'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpensesTab(),
                const Center(
                  child: Text(
                    'Balances',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const Center(
                  child: Text('Photos', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CreateExpenseScreen(groupId: widget.group.id),
            ),
          ).then((_) => _loadExpenses());
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Trip icon
          Container(
            decoration: BoxDecoration(
              color: _getIconColor(widget.group.iconName).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              _getIconData(widget.group.iconName),
              color: _getIconColor(widget.group.iconName),
              size: 40,
            ),
          ),
          const SizedBox(height: 8),
          // Trip name
          Text(
            widget.group.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.beach_access; // Default icon
    }

    // Map string iconName to IconData
    final iconMap = {
      'beach_access': Icons.beach_access,
      'flight': Icons.flight,
      'hiking': Icons.hiking,
      'hotel': Icons.hotel,
      'restaurant': Icons.restaurant,
      'local_bar': Icons.local_bar,
      'train': Icons.train,
      'directions_car': Icons.directions_car,
      'camera_alt': Icons.camera_alt,
      'festival': Icons.festival,
      'sports_kabaddi': Icons.sports_kabaddi,
      'movie': Icons.movie,
    };

    return iconMap[iconName] ?? Icons.beach_access;
  }

  Color _getIconColor(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Colors.amber; // Default color
    }

    // Map iconName to colors
    final colorMap = {
      'beach_access': Colors.amber,
      'flight': Colors.lightBlue,
      'hiking': Colors.green,
      'hotel': Colors.purple,
      'restaurant': Colors.orange,
      'local_bar': Colors.deepOrange,
      'train': Colors.indigo,
      'directions_car': Colors.blue,
      'camera_alt': Colors.pink,
      'festival': Colors.deepPurple,
      'sports_kabaddi': Colors.teal,
      'movie': Colors.red,
    };

    return colorMap[iconName] ?? Colors.amber;
  }

  Widget _buildExpensesTab() {
    return Consumer<ExpensesProvider>(
      builder: (context, expensesProvider, child) {
        final expenses = expensesProvider.getGroupExpenses(widget.group.id);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user?.uid;
        final currency = widget.group.currency;

        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        // Calculate total and personal expenses
        double totalExpenses = 0;
        double myExpenses = 0;

        for (final expense in expenses) {
          totalExpenses += expense.amount;
          if (expense.splitAmounts.containsKey(currentUserId)) {
            myExpenses += expense.splitAmounts[currentUserId] ?? 0;
          }
        }

        // Group expenses by date
        final Map<String, List<ExpenseModel>> groupedExpenses = {};

        for (final expense in expenses) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = today.subtract(const Duration(days: 1));
          final expenseDate = DateTime(
            expense.date.year,
            expense.date.month,
            expense.date.day,
          );

          String dateKey;
          if (expenseDate == today) {
            dateKey = 'Today';
          } else if (expenseDate == yesterday) {
            dateKey = 'Yesterday';
          } else {
            dateKey = DateFormat('MMM d').format(expense.date);
          }

          if (!groupedExpenses.containsKey(dateKey)) {
            groupedExpenses[dateKey] = [];
          }
          groupedExpenses[dateKey]!.add(expense);
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expense summary
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Expenses',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency${myExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total Expenses',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency${totalExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Expenses list grouped by date
              if (expenses.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No expenses yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first expense using the + button',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...groupedExpenses.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...entry.value.map(
                        (expense) => _buildExpenseItem(expense, currentUserId),
                      ),
                    ],
                  );
                }),

              // Extra space at the bottom for FAB
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense, String? currentUserId) {
    final isPaidByCurrentUser = expense.paidById == currentUserId;
    final currency = widget.group.currency;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpenseDetailsScreen(expense: expense),
          ),
        ).then((_) => _loadExpenses());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Category icon
            _getCategoryIcon(expense.category),
            const SizedBox(width: 16),

            // Expense details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: _getPaidByText(
                      expense.paidById,
                      isPaidByCurrentUser,
                    ),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Paid by...',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '$currency${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getPaidByText(
    String paidById,
    bool isPaidByCurrentUser,
  ) async {
    if (isPaidByCurrentUser) {
      return 'Paid by Me (me)';
    }
    final userName = await UserService().getUserDisplayName(paidById);
    return 'Paid by $userName';
  }

  Widget _getCategoryIcon(String? category) {
    IconData iconData;
    Color color;

    switch (category?.toLowerCase()) {
      case 'food':
        iconData = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'drinks':
        iconData = Icons.local_bar;
        color = Colors.amber;
        break;
      case 'transport':
      case 'transportation':
        iconData = Icons.directions_car;
        color = Colors.blue;
        break;
      case 'accommodation':
      case 'hotel':
        iconData = Icons.hotel;
        color = Colors.purple;
        break;
      case 'entertainment':
        iconData = Icons.movie;
        color = Colors.red;
        break;
      case 'shopping':
        iconData = Icons.shopping_bag;
        color = Colors.pink;
        break;
      case 'code':
        iconData = Icons.code;
        color = Colors.green;
        break;
      default:
        iconData = Icons.receipt;
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 22),
    );
  }
}
