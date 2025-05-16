import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/group_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/groups_provider.dart';
import '../../expenses/screens/create_expense_screen.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../expenses/widgets/expense_list_item.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({required this.group, super.key});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
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
        title: Text(
          widget.group.name,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showGroupOptions();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [Tab(text: 'Expenses'), Tab(text: 'Members')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildExpensesTab(), _buildMembersTab()],
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
        backgroundColor: const Color(0xFF003366), // Dark blue background
        shape: CircleBorder(
          side: BorderSide(color: Colors.blue, width: 2.0), // Light blue border
        ),
        child: const Icon(
          Icons.add,
          color: Colors.blue, // Light blue plus icon
          size: 36,
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    return Consumer<ExpensesProvider>(
      builder: (context, expensesProvider, child) {
        final expenses = expensesProvider.getGroupExpenses(widget.group.id);

        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'No expenses yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Add your first expense to start tracking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadExpenses,
          color: Colors.blue,
          backgroundColor: Colors.grey.shade900,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return ExpenseListItem(expense: expense);
            },
          ),
        );
      },
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<List<String>>(
      future: _loadMemberNames(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading members: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final memberNames = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: memberNames.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Text(
                    memberNames[index].isNotEmpty
                        ? memberNames[index][0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
                title: Text(
                  memberNames[index],
                  style: const TextStyle(color: Colors.white),
                ),
                // We'll add more member-specific functionality later
              ),
            );
          },
        );
      },
    );
  }

  // Placeholder for loading member names - this will be implemented fully later
  Future<List<String>> _loadMemberNames() async {
    // In a real implementation, we would fetch user details from Firestore
    // For now, return placeholder data
    await Future.delayed(const Duration(milliseconds: 500));
    return ['You', 'Friend 1', 'Friend 2'];
  }

  void _showGroupOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.blue),
                title: const Text(
                  'Add Member',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Will implement add member functionality later
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text(
                  'Edit Trip',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Will implement edit trip functionality later
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Trip',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteGroup();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Delete Trip',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${widget.group.name}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteGroup();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGroup() async {
    setState(() {
      _isLoading = true;
    });

    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await groupsProvider.deleteGroup(widget.group.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pop(context);
      AppUtils.showSnackBar(context, 'Trip deleted successfully');
    } else {
      AppUtils.showSnackBar(
        context,
        groupsProvider.errorMessage ?? 'Failed to delete trip',
        isError: true,
      );
    }
  }
}
