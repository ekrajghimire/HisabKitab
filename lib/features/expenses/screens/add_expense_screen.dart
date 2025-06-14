import 'package:flutter/material.dart';
import 'package:hisabkitab/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expenses_provider.dart';
import '../../../core/services/user_service.dart';

enum SplitType { equally, asParts, asAmount }

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<String> participants;
  final Map<String, String> participantNames;

  const AddExpenseScreen({
    required this.groupId,
    required this.participants,
    required this.participantNames,
    super.key,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final Map<String, TextEditingController> _participantAmountControllers = {};
  final Map<String, int> _participantParts = {};

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedPaidBy;
  SplitType _splitType = SplitType.equally;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('MMM d, yyyy').format(_selectedDate);
    _initializeParticipantControllers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    for (var controller in _participantAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeParticipantControllers() {
    for (final userId in widget.participants) {
      _participantAmountControllers[userId] = TextEditingController();
      _participantParts[userId] = 1;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF303030),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.grey.shade900),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        _dateController.text = DateFormat('MMM d, yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF303030),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.grey.shade900),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _updateSplitAmounts() {
    if (_amountController.text.isEmpty) return;
    final totalAmount = double.tryParse(_amountController.text);
    if (totalAmount == null) return;

    switch (_splitType) {
      case SplitType.equally:
        final activeParticipants = widget.participants.length;
        if (activeParticipants > 0) {
          // Calculate base amount and remainder
          final baseAmount = (totalAmount / activeParticipants).floorToDouble();
          final remainder = totalAmount - (baseAmount * activeParticipants);

          // Distribute the remainder to make the total exact
          for (var i = 0; i < widget.participants.length; i++) {
            final userId = widget.participants[i];
            final amount = baseAmount + (i < remainder ? 1 : 0);
            _participantAmountControllers[userId]?.text = amount
                .toStringAsFixed(2);
          }
        }
        break;
      case SplitType.asParts:
        final totalParts = _participantParts.values.fold<int>(
          0,
          (sum, parts) => sum + parts,
        );
        if (totalParts > 0) {
          // Calculate base amount and remainder
          final baseAmount = (totalAmount / totalParts).floorToDouble();
          var remainingAmount = totalAmount;

          // Distribute amounts to all but the last participant
          for (var i = 0; i < widget.participants.length - 1; i++) {
            final userId = widget.participants[i];
            final parts = _participantParts[userId] ?? 1;
            final amount = (baseAmount * parts).floorToDouble();
            _participantAmountControllers[userId]?.text = amount
                .toStringAsFixed(2);
            remainingAmount -= amount;
          }

          // Give remaining amount to the last participant
          final lastUserId = widget.participants.last;
          _participantAmountControllers[lastUserId]?.text = remainingAmount
              .toStringAsFixed(2);
        }
        break;
      case SplitType.asAmount:
        // Manual entry - no automatic updates
        break;
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaidBy == null) {
      setState(() => _errorMessage = 'Please select who paid');
      return;
    }

    final totalAmount = double.tryParse(_amountController.text);
    if (totalAmount == null || totalAmount <= 0) {
      setState(
        () => _errorMessage = 'Please enter a valid amount greater than 0',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Map<String, double> splitAmounts = {};
    double totalSplitAmount = 0;

    // Validate split amounts
    for (final userId in widget.participants) {
      final amountText = _participantAmountControllers[userId]?.text ?? '0';
      final amount = double.tryParse(amountText) ?? 0;
      splitAmounts[userId] = amount;
      totalSplitAmount += amount;
    }

    // Check if split amounts match total with a small tolerance
    if ((totalSplitAmount - totalAmount).abs() > 0.001) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Split amounts do not match the total amount';
      });
      return;
    }

    debugPrint('Creating expense with data:');
    debugPrint('Title: ${_titleController.text.trim()}');
    debugPrint('Amount: $totalAmount');
    debugPrint('Paid By: $_selectedPaidBy');
    debugPrint('Split Amounts: $splitAmounts');
    debugPrint('Group ID: ${widget.groupId}');

    try {
      final expensesProvider = Provider.of<ExpensesProvider>(
        context,
        listen: false,
      );
      final expense = await expensesProvider.createExpense(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        amount: totalAmount,
        paidById: _selectedPaidBy!,
        splitAmounts: splitAmounts,
        category: 'Other',
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
      );

      if (!mounted) return;

      if (expense != null) {
        debugPrint('Expense created successfully: ${expense.id}');
        Navigator.pop(context, expense);
      } else {
        final error = expensesProvider.errorMessage;
        debugPrint('Failed to create expense: $error');
        setState(() {
          _errorMessage =
              error ?? 'Failed to create expense. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating expense: $e\nStackTrace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    final currentUserName = authProvider.userModel?.name ?? 'Me';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      // Title field
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          prefixIcon: const Icon(
                            Icons.title,
                            color: Colors.grey,
                          ),
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade900,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: const Icon(
                            Icons.attach_money,
                            color: Colors.grey,
                          ),
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade900,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty &&
                              double.tryParse(value) != null) {
                            _updateSplitAmounts();
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Paid By dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedPaidBy,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Paid By',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Colors.grey,
                          ),
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade900,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items:
                            widget.participants.map((userId) {
                              String name;
                              if (userId == currentUserId) {
                                name = '$currentUserName (me)';
                              } else {
                                name =
                                    widget.participantNames[userId] ?? userId;
                              }
                              return DropdownMenuItem(
                                value: userId,
                                child: Text(name),
                              );
                            }).toList(),
                        onChanged: (String? value) {
                          setState(() => _selectedPaidBy = value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Date and Time picker
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dateController,
                              style: const TextStyle(color: Colors.white),
                              readOnly: true,
                              onTap: _selectDate,
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                ),
                                labelStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey.shade900,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _selectTime,
                            icon: const Icon(
                              Icons.access_time,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Split section
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
                              'Split',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<SplitType>(
                              segments: const [
                                ButtonSegment(
                                  value: SplitType.equally,
                                  label: Text('Equally'),
                                ),
                                ButtonSegment(
                                  value: SplitType.asParts,
                                  label: Text('As Parts'),
                                ),
                                ButtonSegment(
                                  value: SplitType.asAmount,
                                  label: Text('As Amount'),
                                ),
                              ],
                              selected: {_splitType},
                              onSelectionChanged: (
                                Set<SplitType> newSelection,
                              ) {
                                setState(() {
                                  _splitType = newSelection.first;
                                  _updateSplitAmounts();
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                              ? Colors.blue
                                              : Colors.transparent,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Participants list
                      ...widget.participants.map((userId) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.participantNames[userId] ??
                                        'Unknown User',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (_splitType == SplitType.asParts) ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _participantParts[userId] =
                                            (_participantParts[userId] ?? 1) -
                                            1;
                                        if ((_participantParts[userId] ?? 0) <
                                            0) {
                                          _participantParts[userId] = 0;
                                        }
                                        _updateSplitAmounts();
                                      });
                                    },
                                  ),
                                  Text(
                                    '${_participantParts[userId] ?? 1}x',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _participantParts[userId] =
                                            (_participantParts[userId] ?? 1) +
                                            1;
                                        _updateSplitAmounts();
                                      });
                                    },
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller:
                                          _participantAmountControllers[userId],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      enabled: _splitType == SplitType.asAmount,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 0,
                                            ),
                                        filled: true,
                                        fillColor:
                                            _splitType == SplitType.asAmount
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade900,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 24),

                      // Save button
                      ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Expense',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
