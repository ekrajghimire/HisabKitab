import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/expense_model.dart';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ExpensesProvider with ChangeNotifier {
  final MongoDBService _mongoDb = MongoDBService.instance;

  final Map<String, List<ExpenseModel>> _groupExpenses = {};
  final Set<String> _savingToMongo = {}; // Track items being saved
  String? _errorMessage;
  bool _isLoading = false;
  bool _isOnline = true;

  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;

  ExpensesProvider() {
    // Initialize connectivity listener
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      // If we just came back online, trigger a sync
      if (!wasOnline && _isOnline) {
        _syncExpenses();
      }
      notifyListeners();
    });

    // Load any existing local data on startup
    _loadLocalData();
  }

  // Load local data on startup
  Future<void> _loadLocalData() async {
    try {
      final localExpenses = await LocalStorageService.getAllExpenses();
      if (localExpenses.isNotEmpty) {
        // Group expenses by groupId
        _groupExpenses.clear();
        for (final expense in localExpenses) {
          if (_groupExpenses[expense.groupId] == null) {
            _groupExpenses[expense.groupId] = [];
          }
          _groupExpenses[expense.groupId]!.add(expense);
        }

        // Sort each group's expenses by date (descending)
        _groupExpenses.forEach((groupId, expenses) {
          expenses.sort((a, b) => b.date.compareTo(a.date));
        });

        notifyListeners();
        debugPrint(
          'Loaded ${localExpenses.length} expenses from local storage on startup',
        );
      }
    } catch (e) {
      debugPrint('Error loading local expenses on startup: $e');
    }
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }

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

  Future<void> _syncExpenses() async {
    if (!_isOnline) return;

    try {
      // Get all group IDs from local expenses
      final localExpenses = await LocalStorageService.getAllExpenses();
      final groupIds = localExpenses.map((e) => e.groupId).toSet();

      for (final groupId in groupIds) {
        // Get MongoDB expenses for this group
        final mongoExpenses =
            (await _mongoDb.getExpensesForGroup(
              groupId,
            )).map((data) => ExpenseModel.fromMap(data)).toList();

        // Get local expenses for this group
        final groupLocalExpenses =
            localExpenses.where((e) => e.groupId == groupId).toList();

        // Compare and sync
        for (final localExpense in groupLocalExpenses) {
          final mongoExpense = mongoExpenses.firstWhere(
            (e) => e.id == localExpense.id,
            orElse: () => localExpense,
          );

          // If local expense is newer or MongoDB doesn't have it
          if (localExpense.updatedAt.isAfter(mongoExpense.updatedAt)) {
            await _mongoDb.saveExpense(localExpense.toMap());
          }
        }

        // Update local storage with any new expenses from MongoDB
        for (final mongoExpense in mongoExpenses) {
          final localExpense = groupLocalExpenses.firstWhere(
            (e) => e.id == mongoExpense.id,
            orElse: () => mongoExpense,
          );

          // If MongoDB expense is newer or local doesn't have it
          if (mongoExpense.updatedAt.isAfter(localExpense.updatedAt)) {
            await LocalStorageService.saveExpense(mongoExpense);
          }
        }
      }

      // Update last sync timestamp
      await LocalStorageService.updateLastSyncTimestamp();
    } catch (e) {
      debugPrint('Error during expense sync: $e');
    }
  }

  Future<void> fetchGroupExpenses(String groupId) async {
    if (_isLoading) return;

    try {
      debugPrint('ExpensesProvider: Fetching expenses for group $groupId');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Always load from local storage first for instant response
      List<ExpenseModel> expenses =
          await LocalStorageService.getExpensesForGroup(groupId);

      // Update UI immediately with local data
      expenses.sort((a, b) => b.date.compareTo(a.date));
      _groupExpenses[groupId] = expenses;
      _isLoading = false;
      notifyListeners();
      debugPrint(
        'ExpensesProvider: Loaded ${expenses.length} expenses from local storage',
      );

      // Try to get from MongoDB in background if online
      if (_isOnline && _mongoDb.isConnected) {
        _fetchFromMongoInBackground(groupId);
      }
    } catch (e, stackTrace) {
      debugPrint(
        'ExpensesProvider: Error fetching expenses: $e\nStackTrace: $stackTrace',
      );
      _isLoading = false;
      _errorMessage = 'Failed to fetch expenses: ${e.toString()}';
      notifyListeners();
    }
  }

  // Background fetch from MongoDB - non-blocking
  void _fetchFromMongoInBackground(String groupId) async {
    try {
      final expensesData = await _mongoDb.getExpensesForGroup(groupId);
      final mongoExpenses =
          expensesData.map((e) => ExpenseModel.fromMap(e)).toList();

      // Save to local storage
      for (final expense in mongoExpenses) {
        await LocalStorageService.saveExpense(expense);
      }

      // Update UI with fresh data only if we got more/different data
      final currentLocal = _groupExpenses[groupId] ?? [];
      if (mongoExpenses.length != currentLocal.length ||
          _hasNewData(mongoExpenses, currentLocal)) {
        mongoExpenses.sort((a, b) => b.date.compareTo(a.date));
        _groupExpenses[groupId] = mongoExpenses;
        notifyListeners();
        debugPrint(
          'ExpensesProvider: Updated with ${mongoExpenses.length} expenses from MongoDB',
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch from MongoDB in background: $e');
    }
  }

  // Helper to check if we have new data
  bool _hasNewData(
    List<ExpenseModel> mongoExpenses,
    List<ExpenseModel> localExpenses,
  ) {
    if (mongoExpenses.isEmpty && localExpenses.isEmpty) return false;
    if (mongoExpenses.isEmpty || localExpenses.isEmpty) return true;

    // Check if any MongoDB expense is newer than local
    for (final mongoExpense in mongoExpenses) {
      final localExpense = localExpenses.firstWhere(
        (e) => e.id == mongoExpense.id,
        orElse:
            () => ExpenseModel(
              id: '',
              groupId: '',
              title: '',
              amount: 0,
              paidById: '',
              splitAmounts: {},
              date: DateTime(1970),
              createdAt: DateTime(1970),
              updatedAt: DateTime(1970),
            ),
      );

      if (localExpense.id.isEmpty ||
          mongoExpense.updatedAt.isAfter(localExpense.updatedAt)) {
        return true;
      }
    }
    return false;
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

      // Save to local storage first - this is fast
      await LocalStorageService.saveExpense(newExpense);

      // Update local state immediately for instant UI update
      if (_groupExpenses.containsKey(groupId)) {
        _groupExpenses[groupId]!.insert(0, newExpense);
      } else {
        _groupExpenses[groupId] = [newExpense];
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('ExpensesProvider: Expense creation completed');

      // Try to save to MongoDB in background - don't block UI
      if (_isOnline) {
        _saveExpenseToMongoInBackground(newExpense);
      } else {
        // Queue for later sync when offline
        await LocalStorageService.markForSync(newExpense.id, 'expenses');
      }

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

  // Background save to MongoDB - non-blocking
  void _saveExpenseToMongoInBackground(ExpenseModel expense) async {
    // Prevent duplicate saves
    if (_savingToMongo.contains(expense.id)) {
      debugPrint('Expense ${expense.id} already being saved to MongoDB');
      return;
    }

    _savingToMongo.add(expense.id);
    try {
      if (_mongoDb.isConnected) {
        await _mongoDb.saveExpense(expense.toMap());
        debugPrint('Expense saved to MongoDB successfully in background');
      } else {
        debugPrint('MongoDB not connected - queueing expense for sync');
        await LocalStorageService.markForSync(expense.id, 'expenses');
      }
    } catch (e) {
      debugPrint('Failed to save expense to MongoDB in background: $e');
      // Queue for later sync
      await LocalStorageService.markForSync(expense.id, 'expenses');
    } finally {
      _savingToMongo.remove(expense.id);
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

      // Save to local storage first
      await LocalStorageService.saveExpense(updatedExpense);

      // Try to save to MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.saveExpense(updatedData);
        } catch (e) {
          debugPrint('Failed to save to MongoDB: $e');
          // Continue since we have local copy
        }
      }

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

      // Delete from local storage first
      await LocalStorageService.deleteExpense(expenseId);

      // Try to delete from MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.deleteExpense(expenseId);
        } catch (e) {
          debugPrint('Failed to delete from MongoDB: $e');
          // Continue since we've deleted from local storage
        }
      }

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
