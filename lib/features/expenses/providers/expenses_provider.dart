import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/expense_model.dart';

class ExpensesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<ExpenseModel>> _groupExpenses = {};
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
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final querySnapshot =
          await _firestore
              .collection(AppConstants.expensesCollection)
              .where('groupId', isEqualTo: groupId)
              .orderBy('date', descending: true)
              .get();

      final expenses =
          querySnapshot.docs
              .map((doc) => ExpenseModel.fromMap(doc.data()..['id'] = doc.id))
              .toList();

      _groupExpenses[groupId] = expenses;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
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

      await _firestore
          .collection(AppConstants.expensesCollection)
          .doc(expenseId)
          .set(newExpense.toMap());

      // Update local state
      if (_groupExpenses.containsKey(groupId)) {
        _groupExpenses[groupId]!.insert(0, newExpense);
      } else {
        _groupExpenses[groupId] = [newExpense];
      }

      _isLoading = false;
      notifyListeners();

      return newExpense;
    } catch (e) {
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
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _firestore
          .collection(AppConstants.expensesCollection)
          .doc(updatedExpense.id)
          .update(updatedData);

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

      await _firestore
          .collection(AppConstants.expensesCollection)
          .doc(expenseId)
          .delete();

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
