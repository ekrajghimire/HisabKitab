import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/group_model.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettlementsScreen extends StatefulWidget {
  final GroupModel group;

  const SettlementsScreen({required this.group, super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final authProvider = Provider.of<AuthProvider>(context);
    final expensesProvider = Provider.of<ExpensesProvider>(context);

    // Get balances from the expenses provider
    final balances = expensesProvider.getGroupBalances(widget.group.id);
    final currentUserId = authProvider.user?.uid;

    // Calculate who owes whom
    final settlements = <Map<String, dynamic>>[];

    // For now, just show a simplified version with the current user
    if (currentUserId != null && balances.containsKey(currentUserId)) {
      final userBalance = balances[currentUserId]!;

      if (userBalance > 0) {
        // User is owed money
        settlements.add({
          'type': 'receive',
          'amount': userBalance,
          'name': 'Others',
          'message': 'You are owed',
        });
      } else if (userBalance < 0) {
        // User owes money
        settlements.add({
          'type': 'pay',
          'amount': userBalance.abs(),
          'name': 'Others',
          'message': 'You owe',
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Settlements', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : settlements.isEmpty
              ? _buildEmptyState()
              : _buildSettlementsList(settlements, currencyFormat),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'All settled up!',
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
              'There are no outstanding balances in this trip.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsList(
    List<Map<String, dynamic>> settlements,
    NumberFormat currencyFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Trip Balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final settlement = settlements[index];
              final isReceiving = settlement['type'] == 'receive';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                isReceiving
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            child: Icon(
                              isReceiving
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isReceiving ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settlement['message'],
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(settlement['amount']),
                                style: TextStyle(
                                  color:
                                      isReceiving ? Colors.green : Colors.red,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isReceiving ? 'From' : 'To',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            settlement['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Add a settle up button at the bottom
        if (settlements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                // Will implement settle up functionality later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settle up functionality coming soon!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'SETTLE UP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
