import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/expense_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/expenses_provider.dart';

class ExpenseDetailsScreen extends StatefulWidget {
  final ExpenseModel expense;

  const ExpenseDetailsScreen({required this.expense, super.key});

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late ExpenseModel _expense;
  bool _isLoading = false;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    _titleController = TextEditingController(text: _expense.title);
    _amountController = TextEditingController(text: _expense.amount.toString());
    _descriptionController = TextEditingController(
      text: _expense.description ?? '',
    );
    _selectedCategory = _expense.category ?? 'Other';
    _selectedDate = _expense.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final expensesProvider = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    );

    try {
      final updatedExpense = _expense.copyWith(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        description:
            _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
        category: _selectedCategory,
        date: _selectedDate,
      );

      final success = await expensesProvider.updateExpense(updatedExpense);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (success) {
          _expense = updatedExpense;
          _isEditing = false;
          AppUtils.showSnackBar(context, 'Expense updated successfully');
        } else {
          AppUtils.showSnackBar(
            context,
            expensesProvider.errorMessage ?? 'Failed to update expense',
            isError: true,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppUtils.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteExpense() async {
    setState(() {
      _isLoading = true;
    });

    final expensesProvider = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    );

    try {
      final success = await expensesProvider.deleteExpense(
        _expense.id,
        _expense.groupId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate successful deletion
        AppUtils.showSnackBar(context, 'Expense deleted successfully');
      } else {
        setState(() {
          _isLoading = false;
        });
        AppUtils.showSnackBar(
          context,
          expensesProvider.errorMessage ?? 'Failed to delete expense',
          isError: true,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppUtils.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'Delete Expense',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete this expense?\nThis action cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (result == true) {
      await _deleteExpense();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF303030),
              onSurface: Colors.white,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.grey.shade900),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMMM d, yyyy');
    final isPaidByCurrentUser = _expense.paidById == authProvider.user?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Expense Details',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _toggleEditMode,
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child:
                    _isEditing
                        ? _buildEditForm()
                        : _buildExpenseDetails(
                          currencyFormat,
                          dateFormat,
                          isPaidByCurrentUser,
                        ),
              ),
      bottomNavigationBar:
          _isEditing
              ? BottomAppBar(
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _toggleEditMode,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _updateExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('SAVE'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildExpenseDetails(
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    bool isPaidByCurrentUser,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with amount and category
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _expense.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    currencyFormat.format(_expense.amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildCategoryIcon(_expense.category),
                      const SizedBox(width: 8),
                      Text(
                        _expense.category ?? 'Other',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dateFormat.format(_expense.date),
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Paid by section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paid by',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaidByCurrentUser ? 'You' : 'Someone else',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(_expense.amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Split information section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Split Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.grey),
              const SizedBox(height: 12),
              // Currently showing a simplified version - will be expanded in future
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'You',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    currencyFormat.format(_expense.splitAmounts.values.first),
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Description section (if present)
        if (_expense.description != null && _expense.description!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _expense.description!,
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Receipt section (if present)
        if (_expense.receiptUrl != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Placeholder for receipt image - to be implemented in future
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.receipt, color: Colors.grey, size: 64),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Additional meta data
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Created on ${dateFormat.format(_expense.createdAt)}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
              if (_expense.updatedAt != _expense.createdAt) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.update, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Last updated on ${dateFormat.format(_expense.updatedAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          TextFormField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'What was this expense for?',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Amount field
          TextFormField(
            controller: _amountController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: '0.00',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixText: '\$ ',
              prefixStyle: const TextStyle(color: Colors.white),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              try {
                final amount = double.parse(value);
                if (amount <= 0) {
                  return 'Amount must be greater than zero';
                }
              } catch (e) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Category dropdown
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: Colors.grey.shade800,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            items:
                [
                  'Food',
                  'Drinks',
                  'Transport',
                  'Accommodation',
                  'Entertainment',
                  'Shopping',
                  'Code',
                  'Other',
                ].map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          // Date picker
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(
                  Icons.calendar_today,
                  color: Colors.grey,
                ),
              ),
              child: Text(
                DateFormat('MMMM d, yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Description field
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Add additional details',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
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
      child: Icon(iconData, color: color, size: 18),
    );
  }
}
