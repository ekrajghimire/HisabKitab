import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/expense_model.dart';
import '../../../core/services/user_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/expense_details_screen.dart';

class ExpenseListItem extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;

  const ExpenseListItem({required this.expense, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isPaidByCurrentUser = expense.paidById == authProvider.user?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade900,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpenseDetailsScreen(expense: expense),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icon or default
                  _buildCategoryIcon(expense.category),
                  const SizedBox(width: 12),

                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (expense.description != null &&
                            expense.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              expense.description!,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Amount
                  Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Footer with date and paid by info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(expense.date),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  FutureBuilder<String>(
                    future: _getPaidByText(
                      expense.paidById,
                      isPaidByCurrentUser,
                    ),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ??
                            (isPaidByCurrentUser
                                ? 'Paid by You'
                                : 'Paid by...'),
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Receipt indicator if there's a receipt
              if (expense.receiptUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt,
                        color: Colors.grey.shade500,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Receipt attached',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getPaidByText(
    String paidById,
    bool isPaidByCurrentUser,
  ) async {
    if (isPaidByCurrentUser) {
      return 'Paid by You';
    }

    final userName = await UserService().getUserDisplayName(paidById);
    return 'Paid by $userName';
  }

  Widget _buildCategoryIcon(String? category) {
    IconData iconData;
    Color color;

    switch (category?.toLowerCase()) {
      case 'food':
        iconData = Icons.restaurant;
        color = Colors.orange;
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
      child: Icon(iconData, color: color, size: 24),
    );
  }
}
