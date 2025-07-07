import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static const String _tripsKey = 'local_trips';
  static const String _userTripsMapKey = 'user_trips_map';
  static const String _usersKey = 'local_users';
  static const String _expensesKey = 'local_expenses';
  static const String _groupsKey = 'local_groups';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _pendingSyncKey = 'pending_sync_items';

  // Structure for pending sync items:
  // {
  //   "trips": ["trip_id1", "trip_id2"],
  //   "expenses": ["expense_id1"],
  //   "groups": ["group_id1"]
  // }

  // Save a trip to local storage
  static Future<bool> saveTrip(TripModel trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing trips
      List<String> tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      // Convert trip to JSON string
      final tripJson = jsonEncode(trip.toMap()..['id'] = trip.id);

      // Check if trip already exists and update it
      final existingIndex = tripJsonList.indexWhere((json) {
        try {
          final map = jsonDecode(json);
          return map['id'] == trip.id;
        } catch (e) {
          debugPrint('Error parsing existing trip JSON: $e');
          return false;
        }
      });

      if (existingIndex >= 0) {
        // Update existing trip
        tripJsonList[existingIndex] = tripJson;
        debugPrint('Updated existing trip locally: ${trip.id}');
      } else {
        // Add new trip
        tripJsonList.add(tripJson);
        debugPrint('Added new trip locally: ${trip.id}');
      }

      // Save trips
      await prefs.setStringList(_tripsKey, tripJsonList);

      // Update user-trips mapping
      await _updateUserTripsMapping(trip);

      debugPrint('Trip saved locally: ${trip.id}');
      return true;
    } catch (e) {
      debugPrint('Error saving trip locally: $e');
      return false;
    }
  }

  // Retrieve all trips from local storage
  static Future<List<TripModel>> getAllTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      return tripJsonList.map((tripJson) {
        Map<String, dynamic> tripMap = jsonDecode(tripJson);
        return TripModel.fromMap(tripMap);
      }).toList();
    } catch (e) {
      debugPrint('Error retrieving trips: $e');
      return [];
    }
  }

  // Retrieve trips for a specific user
  static Future<List<TripModel>> getTripsForUser(String userId) async {
    try {
      final allTrips = await getAllTrips();
      return allTrips.where((trip) => trip.members.contains(userId)).toList();
    } catch (e) {
      debugPrint('Error retrieving trips for user: $e');
      return [];
    }
  }

  // Update the user-trips mapping
  static Future<void> _updateUserTripsMapping(TripModel trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing mapping
      String mapJson = prefs.getString(_userTripsMapKey) ?? '{}';
      Map<String, dynamic> userTripsMap = jsonDecode(mapJson);

      // Update mapping for each member
      for (String userId in trip.members) {
        List<String> tripIds = List<String>.from(userTripsMap[userId] ?? []);
        if (!tripIds.contains(trip.id)) {
          tripIds.add(trip.id);
        }
        userTripsMap[userId] = tripIds;
      }

      // Save updated mapping
      await prefs.setString(_userTripsMapKey, jsonEncode(userTripsMap));
    } catch (e) {
      debugPrint('Error updating user-trips mapping: $e');
    }
  }

  // Delete a trip
  static Future<bool> deleteTrip(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing trips
      List<String> tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      // Filter out the trip to delete
      tripJsonList =
          tripJsonList.where((tripJson) {
            Map<String, dynamic> tripMap = jsonDecode(tripJson);
            return tripMap['id'] != tripId;
          }).toList();

      // Save updated trips
      await prefs.setStringList(_tripsKey, tripJsonList);

      // Update user-trips mapping (would need to remove this trip from all users)
      // Omitted for simplicity

      return true;
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      return false;
    }
  }

  // Clear all trips data (for testing)
  static Future<void> clearAllTripsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tripsKey);
      await prefs.remove(_userTripsMapKey);
    } catch (e) {
      debugPrint('Error clearing trips data: $e');
    }
  }

  // User methods
  static Future<bool> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      Map<String, dynamic> usersMap = jsonDecode(
        prefs.getString(_usersKey) ?? '{}',
      );

      // Add or update user
      usersMap[user.uid] = user.toMap();

      // Save users
      await prefs.setString(_usersKey, jsonEncode(usersMap));

      debugPrint('User saved locally: ${user.uid}');
      return true;
    } catch (e) {
      debugPrint('Error saving user locally: $e');
      return false;
    }
  }

  static Future<UserModel?> getUser(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersMap = jsonDecode(prefs.getString(_usersKey) ?? '{}');

      if (usersMap[uid] != null) {
        return UserModel.fromMap(usersMap[uid]);
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving user: $e');
      return null;
    }
  }

  // Expense methods
  static Future<bool> saveExpense(ExpenseModel expense) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing expenses
      List<String> expenseJsonList = prefs.getStringList(_expensesKey) ?? [];

      // Convert expense to JSON string
      final expenseJson = jsonEncode(expense.toMap()..['id'] = expense.id);

      // Add new expense or update existing
      final index = expenseJsonList.indexWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == expense.id;
      });

      if (index >= 0) {
        expenseJsonList[index] = expenseJson;
      } else {
        expenseJsonList.add(expenseJson);
      }

      // Save expenses
      await prefs.setStringList(_expensesKey, expenseJsonList);

      debugPrint('Expense saved locally: ${expense.id}');
      return true;
    } catch (e) {
      debugPrint('Error saving expense locally: $e');
      return false;
    }
  }

  static Future<List<ExpenseModel>> getAllExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseJsonList = prefs.getStringList(_expensesKey) ?? [];

      return expenseJsonList
          .map((json) => ExpenseModel.fromMap(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('Error retrieving all expenses: $e');
      return [];
    }
  }

  static Future<List<ExpenseModel>> getExpensesForGroup(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseJsonList = prefs.getStringList(_expensesKey) ?? [];

      return expenseJsonList
          .map((json) => ExpenseModel.fromMap(jsonDecode(json)))
          .where((expense) => expense.groupId == groupId)
          .toList();
    } catch (e) {
      debugPrint('Error retrieving expenses: $e');
      return [];
    }
  }

  static Future<bool> deleteExpense(String expenseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing expenses
      List<String> expenseJsonList = prefs.getStringList(_expensesKey) ?? [];

      // Filter out the expense to delete
      expenseJsonList =
          expenseJsonList.where((json) {
            final map = jsonDecode(json);
            return map['id'] != expenseId;
          }).toList();

      // Save updated expenses
      await prefs.setStringList(_expensesKey, expenseJsonList);

      debugPrint('Expense deleted locally: $expenseId');
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // Sync timestamp methods
  static Future<void> updateLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error updating sync timestamp: $e');
    }
  }

  static Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      debugPrint('Error getting sync timestamp: $e');
      return null;
    }
  }

  // Clear all data
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tripsKey);
      await prefs.remove(_userTripsMapKey);
      await prefs.remove(_usersKey);
      await prefs.remove(_expensesKey);
      await prefs.remove(_groupsKey);
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  // Group methods
  static Future<bool> saveGroup(GroupModel group) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing groups
      Map<String, dynamic> groupsMap = jsonDecode(
        prefs.getString(_groupsKey) ?? '{}',
      );

      // Add or update group
      groupsMap[group.id] = group.toMap();

      // Save groups
      await prefs.setString(_groupsKey, jsonEncode(groupsMap));

      debugPrint('Group saved locally: ${group.id}');
      return true;
    } catch (e) {
      debugPrint('Error saving group locally: $e');
      return false;
    }
  }

  static Future<List<GroupModel>> getAllGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsMap = jsonDecode(prefs.getString(_groupsKey) ?? '{}');

      return groupsMap.values
          .map<GroupModel>((groupData) => GroupModel.fromMap(groupData))
          .toList();
    } catch (e) {
      debugPrint('Error retrieving all groups: $e');
      return [];
    }
  }

  static Future<List<GroupModel>> getGroupsForUser(String userId) async {
    try {
      final groups = await getAllGroups();
      return groups.where((group) => group.memberIds.contains(userId)).toList();
    } catch (e) {
      debugPrint('Error retrieving groups for user: $e');
      return [];
    }
  }

  static Future<bool> deleteGroup(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing groups
      Map<String, dynamic> groupsMap = jsonDecode(
        prefs.getString(_groupsKey) ?? '{}',
      );

      // Remove the group
      groupsMap.remove(groupId);

      // Save updated groups
      await prefs.setString(_groupsKey, jsonEncode(groupsMap));

      debugPrint('Group deleted locally: $groupId');
      return true;
    } catch (e) {
      debugPrint('Error deleting group locally: $e');
      return false;
    }
  }

  static Future<void> markForSync(String itemId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing pending sync items
      final pendingSyncJson = prefs.getString(_pendingSyncKey) ?? '{}';
      Map<String, dynamic> pendingSync = jsonDecode(pendingSyncJson);

      // Initialize list for type if it doesn't exist
      if (!pendingSync.containsKey(type)) {
        pendingSync[type] = [];
      }

      // Add item to sync list if not already present
      List<String> typeList = List<String>.from(pendingSync[type]);
      if (!typeList.contains(itemId)) {
        typeList.add(itemId);
        pendingSync[type] = typeList;
      }

      // Save updated pending sync items
      await prefs.setString(_pendingSyncKey, jsonEncode(pendingSync));
      debugPrint('Marked for sync: $itemId of type $type');
    } catch (e) {
      debugPrint('Error marking item for sync: $e');
    }
  }

  static Future<Map<String, List<String>>> getPendingSyncItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSyncJson = prefs.getString(_pendingSyncKey) ?? '{}';
      Map<String, dynamic> pendingSync = jsonDecode(pendingSyncJson);

      // Convert to correct type
      Map<String, List<String>> result = {};
      pendingSync.forEach((key, value) {
        result[key] = List<String>.from(value);
      });

      return result;
    } catch (e) {
      debugPrint('Error getting pending sync items: $e');
      return {};
    }
  }

  static Future<void> clearSyncItem(String itemId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing pending sync items
      final pendingSyncJson = prefs.getString(_pendingSyncKey) ?? '{}';
      Map<String, dynamic> pendingSync = jsonDecode(pendingSyncJson);

      // Remove item from sync list
      if (pendingSync.containsKey(type)) {
        List<String> typeList = List<String>.from(pendingSync[type]);
        typeList.remove(itemId);
        pendingSync[type] = typeList;

        // Save updated pending sync items
        await prefs.setString(_pendingSyncKey, jsonEncode(pendingSync));
        debugPrint('Cleared sync item: $itemId of type $type');
      }
    } catch (e) {
      debugPrint('Error clearing sync item: $e');
    }
  }
}
