import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/expense_model.dart';
import '../../../core/services/mongo_db_service.dart';

class ExpensesProvider with ChangeNotifier {
  final MongoDBService _mongoDb = MongoDBService.instance;

  final Map<String, List<ExpenseModel>> _groupExpenses = {};
  String? _errorMessage;
  bool _isLoading = false;

  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  List<ExpenseModel> getGroupExpenses(String groupId) {
    return _groupExpenses[groupId] ?? [];
  }

  double getGroupTotal(String groupId) {
    final expenses = _groupExpenses[groupId] ?? [];
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  double getPersonalSpending(String groupId, String userId) {
    final expenses = _groupExpenses[groupId] ?? [];
    return expenses
        .where((expense) => expense.paidById == userId)
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  double getPersonalShare(String groupId, String userId) {
    final expenses = _groupExpenses[groupId] ?? [];
    return expenses.fold(0.0, (sum, expense) {
      return sum + (expense.splitAmounts[userId] ?? 0.0);
    });
  }

  Map<String, double> getGroupBalances(String groupId) {
    final expenses = _groupExpenses[groupId] ?? [];
    final Map<String, double> balances = {};

    for (final expense in expenses) {
      // Add what the payer paid
      balances[expense.paidById] =
          (balances[expense.paidById] ?? 0) + expense.amount;

      // Subtract what each person owes
      expense.splitAmounts.forEach((userId, amount) {
        balances[userId] = (balances[userId] ?? 0) - amount;
      });
    }

    return balances;
  }

  Future<void> fetchGroupExpenses(String groupId) async {
    if (_isLoading) return;

    try {
      debugPrint('ExpensesProvider: Fetching expenses for group $groupId');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final expenses = await _mongoDb.getExpensesForGroup(groupId);
      _groupExpenses[groupId] =
          expenses.map((e) => ExpenseModel.fromMap(e)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      _isLoading = false;
      notifyListeners();
      debugPrint('ExpensesProvider: Fetched ${expenses.length} expenses');
    } catch (e, stackTrace) {
      debugPrint(
        'ExpensesProvider: Error fetching expenses: $e\nStackTrace: $stackTrace',
      );
      _isLoading = false;
      _errorMessage = 'Failed to fetch expenses: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<ExpenseModel?> createExpense({
    required String groupId,
    required String title,
    required double amount,
    required String paidById,
    required Map<String, double> splitAmounts,
    String? description,
    String? category,
    String? receiptUrl,
    DateTime? date,
  }) async {
    try {
      debugPrint('ExpensesProvider: Creating expense...');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final now = DateTime.now();
      final expenseId = const Uuid().v4();
      final expenseDate = date ?? now;

      final newExpense = ExpenseModel(
        id: expenseId,
        groupId: groupId,
        title: title,
        amount: amount,
        paidById: paidById,
        splitAmounts: splitAmounts,
        description: description,
        category: category,
        receiptUrl: receiptUrl,
        date: expenseDate,
        createdAt: now,
        updatedAt: now,
      );

      debugPrint('ExpensesProvider: Saving expense to MongoDB...');
      debugPrint('ExpenseData: ${newExpense.toMap()}');

      // Save to MongoDB
      await _mongoDb.saveExpense(newExpense.toMap());

      // Update local state
      if (_groupExpenses.containsKey(groupId)) {
        _groupExpenses[groupId]!.insert(0, newExpense);
      } else {
        _groupExpenses[groupId] = [newExpense];
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('ExpensesProvider: Expense creation completed');

      return newExpense;
    } catch (e, stackTrace) {
      debugPrint(
        'ExpensesProvider: Error creating expense: $e\nStackTrace: $stackTrace',
      );
      _isLoading = false;
      _errorMessage = 'Failed to create expense: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateExpense(ExpenseModel updatedExpense) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updatedData = {
        ...updatedExpense.toMap(),
        'id': updatedExpense.id,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _mongoDb.saveExpense(updatedData);

      // Update local state
      final groupId = updatedExpense.groupId;
      if (_groupExpenses.containsKey(groupId)) {
        final index = _groupExpenses[groupId]!.indexWhere(
          (expense) => expense.id == updatedExpense.id,
        );

        if (index != -1) {
          _groupExpenses[groupId]![index] = updatedExpense.copyWith(
            updatedAt: DateTime.now(),
          );
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update expense: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String expenseId, String groupId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _mongoDb.deleteExpense(expenseId);

      // Update local state
      if (_groupExpenses.containsKey(groupId)) {
        _groupExpenses[groupId]!.removeWhere(
          (expense) => expense.id == expenseId,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete expense: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
