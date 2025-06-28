import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_model.dart';
import '../../../models/expense_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../expenses/screens/add_expense_screen.dart';
import '../providers/trips_provider.dart';
import '../../../core/services/user_service.dart';
import '../../../core/constants/currency_constants.dart';

class TripDetailScreen extends StatefulWidget {
  final TripModel trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  _TripDetailScreenState createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ExpenseModel> _expenses = [];
  String? _userId;
  Map<String, String> _participantNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
    _loadParticipantNames();
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

  Future<void> _loadParticipantNames() async {
    final userService = UserService();
    final usersData = await userService.getUsersData(widget.trip.members);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    final currentUserName = authProvider.userModel?.name ?? 'Me';

    setState(() {
      _participantNames = {};
      // Add user data from Firestore
      for (final entry in usersData.entries) {
        _participantNames[entry.key] = entry.value.name;
      }

      // Ensure current user is included with correct name
      if (currentUserId != null) {
        _participantNames[currentUserId] = currentUserName;
      }

      // For any missing participants, use a fallback
      for (final memberId in widget.trip.members) {
        if (!_participantNames.containsKey(memberId)) {
          if (memberId == currentUserId) {
            _participantNames[memberId] = currentUserName;
          } else {
            final shortId =
                memberId.length > 8 ? memberId.substring(0, 8) : memberId;
            _participantNames[memberId] = shortId;
          }
        }
      }
    });
  }

  Future<void> _editTrip() async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-trip',
      arguments: widget.trip,
    );

    if (result == true) {
      // Refresh trip details if changes were made
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      await tripsProvider.fetchTrips();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip updated successfully')),
        );
      }
    }
  }

  Future<void> _addExpense() async {
    // Fetch all participant user names from Firestore
    debugPrint('Trip members: ${widget.trip.members}');
    final userService = UserService();
    final usersData = await userService.getUsersData(widget.trip.members);
    debugPrint('Users data from Firestore: $usersData');

    final participantNames = <String, String>{};
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    final currentUserName = authProvider.userModel?.name ?? 'Me';

    // Add user data from Firestore
    for (final entry in usersData.entries) {
      participantNames[entry.key] = entry.value.name;
      debugPrint(
        'Adding participant from Firestore: ${entry.key} -> ${entry.value.name}',
      );
    }

    // Ensure current user is included with correct name
    if (currentUserId != null && !participantNames.containsKey(currentUserId)) {
      participantNames[currentUserId] = currentUserName;
      debugPrint('Adding current user: $currentUserId -> $currentUserName');
    }

    // For any missing participants, try to get basic info or use fallback
    for (final memberId in widget.trip.members) {
      if (!participantNames.containsKey(memberId)) {
        if (memberId == currentUserId) {
          participantNames[memberId] = currentUserName;
        } else {
          final shortId =
              memberId.length > 8 ? memberId.substring(0, 8) : memberId;
          participantNames[memberId] = ' $shortId';
        }
        debugPrint(
          'Adding fallback name for: $memberId -> ${participantNames[memberId]}',
        );
      }
    }

    debugPrint('Final participant names map: $participantNames');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddExpenseScreen(
              groupId: widget.trip.groupId,
              participants: widget.trip.members,
              participantNames: participantNames,
            ),
      ),
    );

    if (result != null && mounted) {
      // Refresh expenses list
      await _loadExpenses();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  Map<String, double> _calculateMemberBalances() {
    final balances = <String, double>{};

    // Initialize balances for all members to 0
    for (final memberId in widget.trip.members) {
      balances[memberId] = 0.0;
    }

    // Add up all expenses paid by each member
    for (final expense in _expenses) {
      final paidById = expense.paidById;
      if (balances.containsKey(paidById)) {
        balances[paidById] = (balances[paidById] ?? 0.0) + expense.amount;
      }
    }

    return balances;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.trip.name),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTrip,
            tooltip: 'Edit Trip',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? Theme.of(context).colorScheme.surface
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                        labelStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        unselectedLabelStyle: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                'Expenses',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Tab(
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                'Balances',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Expense totals
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTotalCard(
                          'My Expenses',
                          '${CurrencyConstants.getSymbol(widget.trip.currency)}${_myExpensesTotal.toStringAsFixed(2)}',
                          Theme.of(context).colorScheme.primary,
                        ),
                        _buildTotalCard(
                          'Total Expenses',
                          '${CurrencyConstants.getSymbol(widget.trip.currency)}${_totalExpenses.toStringAsFixed(2)}',
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Expenses tab
                        _buildExpensesTab(),

                        // Balances tab
                        _buildBalancesTab(),
                      ],
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTotalCard(String title, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    final groupedExpenses = _groupedExpenses;
    final sortedDates =
        groupedExpenses.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // Sort by most recent

    if (groupedExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first expense using the + button',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ...expenses.map((expense) => _buildExpenseItem(expense)),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final payerName = _participantNames[expense.paidById] ?? 'Unknown';
    final isCurrentUser = expense.paidById == _userId;
    final displayName = isCurrentUser ? 'You' : payerName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color:
          isDarkMode
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getCategoryEmoji(expense.category),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paid by $displayName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${CurrencyConstants.getSymbol(widget.trip.currency)}${expense.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(expense.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String? category) {
    if (category == null) return '💰';

    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'drinks':
        return '🥤';
      case 'transport':
        return '🚗';
      case 'accommodation':
        return '🏨';
      case 'activities':
        return '🎯';
      case 'shopping':
        return '🛍️';
      default:
        return '💰';
    }
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

  Widget _buildBalancesTab() {
    final members = widget.trip.members;
    final currency = widget.trip.currency;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    final currentUserName = authProvider.userModel?.name ?? 'Me';

    // Calculate member balances
    final balances = _calculateMemberBalances();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final memberId = members[index];
        final isMe = memberId == currentUserId;
        final displayName = isMe ? '$currentUserName (me)' : memberId;
        final balance = balances[memberId] ?? 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade800,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                '${CurrencyConstants.getSymbol(currency)} ${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: balance > 0 ? Colors.green : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
