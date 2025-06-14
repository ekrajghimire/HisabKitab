import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  static MongoDBService get instance => _instance;

  // Replace with your actual MongoDB Atlas connection string
  static const String _connectionString =
      'mongodb+srv://hisabkitabdb:hisabkitabpassword@hisabkitabcluster.vanbrth.mongodb.net/hisabkitab?retryWrites=true&w=majority';
  Db? _db;
  bool _isConnected = false;

  // Collection names
  static const String usersCollection = 'users';
  static const String tripsCollection = 'trips';
  static const String groupsCollection = 'groups';
  static const String expensesCollection = 'expenses';

  MongoDBService._internal();

  bool get isConnected => _isConnected;
  Db? get db => _db;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      debugPrint('MongoDBService: Attempting to connect...');
      _db = await Db.create(_connectionString);
      await _db!.open();
      _isConnected = true;
      debugPrint('MongoDBService: Connected successfully');

      // Verify connection by listing collections
      final collections = await _db!.getCollectionNames();
      debugPrint('MongoDBService: Available collections: $collections');

      // Create indexes if needed
      await _createIndexes();
    } catch (e, stackTrace) {
      _isConnected = false;
      debugPrint(
        'MongoDBService: Failed to connect: $e\nStackTrace: $stackTrace',
      );
      rethrow;
    }
  }

  Future<void> _createIndexes() async {
    try {
      final expenses = collection(expensesCollection);
      if (expenses == null) return;

      // Create index on groupId for faster expense queries
      await expenses.createIndex(keys: {'groupId': 1}, name: 'groupId_index');

      // Create index on date for sorting
      await expenses.createIndex(keys: {'date': -1}, name: 'date_index');

      debugPrint('MongoDBService: Created indexes successfully');
    } catch (e) {
      debugPrint('MongoDBService: Failed to create indexes: $e');
    }
  }

  Future<void> close() async {
    if (_isConnected && _db != null) {
      await _db!.close();
      _isConnected = false;
      debugPrint('MongoDBService: Connection closed');
    }
  }

  DbCollection? collection(String name) {
    if (!_isConnected || _db == null) {
      debugPrint('MongoDBService: Not connected. Attempting to reconnect...');
      connect().then((_) {
        debugPrint(
          'MongoDBService: Reconnection ${_isConnected ? 'successful' : 'failed'}',
        );
      });
      return null;
    }
    return _db!.collection(name);
  }

  // User methods
  Future<void> saveUser(Map<String, dynamic> user) async {
    await connect();
    final users = collection(usersCollection);
    if (users == null) throw Exception('Failed to access users collection');
    await users.updateOne(
      where.eq('uid', user['uid']),
      modify
          .set('name', user['name'])
          .set('email', user['email'])
          .set('photoUrl', user['photoUrl'])
          .set('updatedAt', DateTime.now().millisecondsSinceEpoch),
      upsert: true,
    );
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    await connect();
    final users = collection(usersCollection);
    if (users == null) return null;
    return await users.findOne(where.eq('uid', uid));
  }

  // Trip methods
  Future<void> saveTrip(Map<String, dynamic> trip) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) throw Exception('Failed to access trips collection');
    await trips.updateOne(
      where.eq('id', trip['id']),
      modify
          .set('name', trip['name'])
          .set('description', trip['description'])
          .set('groupId', trip['groupId'])
          .set('createdBy', trip['createdBy'])
          .set('startDate', trip['startDate'])
          .set('endDate', trip['endDate'])
          .set('currency', trip['currency'])
          .set('members', trip['members'])
          .set('createdAt', trip['createdAt'])
          .set('updatedAt', DateTime.now().millisecondsSinceEpoch),
      upsert: true,
    );
    debugPrint('Trip saved: ${trip['name']}');
  }

  Future<List<Map<String, dynamic>>> getTripsForUser(String userId) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) return [];
    final result = await trips.find(where.eq('members', userId)).toList();
    return result.cast<Map<String, dynamic>>();
  }

  // Group methods
  Future<void> saveGroup(Map<String, dynamic> group) async {
    await connect();
    final groups = collection(groupsCollection);
    if (groups == null) throw Exception('Failed to access groups collection');
    await groups.updateOne(
      where.eq('id', group['id']),
      modify
          .set('name', group['name'])
          .set('description', group['description'])
          .set('creatorId', group['creatorId'])
          .set('memberIds', group['memberIds'])
          .set('imageUrl', group['imageUrl'])
          .set('iconName', group['iconName'])
          .set('currency', group['currency'])
          .set('createdAt', group['createdAt'])
          .set('updatedAt', DateTime.now().millisecondsSinceEpoch),
      upsert: true,
    );
  }

  Future<List<Map<String, dynamic>>> getGroupsForUser(String userId) async {
    await connect();
    final groups = collection(groupsCollection);
    if (groups == null) return [];
    final result = await groups.find(where.eq('memberIds', userId)).toList();
    return result.cast<Map<String, dynamic>>();
  }

  Future<void> deleteGroup(String groupId) async {
    await connect();
    final groups = collection(groupsCollection);
    if (groups == null) throw Exception('Failed to access groups collection');
    await groups.remove(where.eq('id', groupId));
  }

  Future<void> addGroupMember(String groupId, String userId) async {
    await connect();
    final groups = collection(groupsCollection);
    if (groups == null) throw Exception('Failed to access groups collection');
    await groups.update(
      where.eq('id', groupId),
      modify.push('memberIds', userId),
    );
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await connect();
    final groups = collection(groupsCollection);
    if (groups == null) throw Exception('Failed to access groups collection');
    await groups.update(
      where.eq('id', groupId),
      modify.pull('memberIds', userId),
    );
  }

  // Expense methods
  Future<void> saveExpense(Map<String, dynamic> expense) async {
    try {
      debugPrint('MongoDBService: Starting expense save process...');

      // Ensure connection
      if (!_isConnected) {
        debugPrint('MongoDBService: Not connected, attempting to connect...');
        await connect();
      }

      final expenses = collection(expensesCollection);
      if (expenses == null) {
        throw Exception('Failed to access expenses collection');
      }

      debugPrint('MongoDBService: Preparing expense data...');
      debugPrint('Original expense data: $expense');

      // Convert timestamps to Int64 for MongoDB
      final now = DateTime.now().millisecondsSinceEpoch;
      expense['date'] = Int64(expense['date'] is int ? expense['date'] : now);
      expense['createdAt'] = Int64(
        expense['createdAt'] is int ? expense['createdAt'] : now,
      );
      expense['updatedAt'] = Int64(
        expense['updatedAt'] is int ? expense['updatedAt'] : now,
      );

      // Convert amount to double if it's an integer
      if (expense['amount'] is int) {
        expense['amount'] = (expense['amount'] as int).toDouble();
      }

      // Convert split amounts to double if they're integers
      final splitAmounts = expense['splitAmounts'] as Map<String, dynamic>;
      splitAmounts.forEach((key, value) {
        if (value is int) {
          splitAmounts[key] = value.toDouble();
        }
      });
      expense['splitAmounts'] = splitAmounts;

      debugPrint('MongoDBService: Processed expense data: $expense');

      // Save to database
      await expenses.updateOne(where.eq('id', expense['id']), {
        r'$set': expense,
      }, upsert: true);

      debugPrint('MongoDBService: Expense saved successfully');
    } catch (e, stackTrace) {
      debugPrint('MongoDBService: Error saving expense: $e');
      debugPrint('MongoDBService: Stack trace: $stackTrace');
      throw Exception('Failed to save expense: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getExpensesForTrip(String tripId) async {
    await connect();
    final expenses = collection(expensesCollection);
    if (expenses == null) return [];
    final result = await expenses.find(where.eq('tripId', tripId)).toList();
    return result.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getExpensesForGroup(String groupId) async {
    await connect();
    final expenses = collection(expensesCollection);
    if (expenses == null) return [];
    final result = await expenses.find(where.eq('groupId', groupId)).toList();
    return result.cast<Map<String, dynamic>>();
  }

  // Trip-related methods
  Future<List<Map<String, dynamic>>> getTrips(String userId) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) return [];

    try {
      final result =
          await trips.find(where.eq('members', userId)).map((doc) {
            // Ensure the _id is converted to a string id
            final Map<String, dynamic> map = {...doc};
            map['id'] = doc['_id'].toHexString();
            map.remove('_id');

            // Convert Int64 timestamps to regular integers
            map['startDate'] = (doc['startDate'] as Int64).toInt();
            map['endDate'] = (doc['endDate'] as Int64).toInt();
            map['createdAt'] = (doc['createdAt'] as Int64).toInt();
            map['updatedAt'] = (doc['updatedAt'] as Int64).toInt();

            return map;
          }).toList();
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      rethrow;
    }
  }

  Future<void> createTrip(Map<String, dynamic> tripData) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) throw Exception('Failed to access trips collection');

    try {
      // Convert string id to ObjectId for MongoDB
      final String id = tripData['id'];
      tripData.remove('id');
      tripData['_id'] = ObjectId.fromHexString(id);

      // Convert DateTime timestamps to Int64 for MongoDB
      tripData['startDate'] = Int64(tripData['startDate'] as int);
      tripData['endDate'] = Int64(tripData['endDate'] as int);
      tripData['createdAt'] = Int64(tripData['createdAt'] as int);
      tripData['updatedAt'] = Int64(tripData['updatedAt'] as int);

      await trips.insert(tripData);
    } catch (e) {
      debugPrint('Error creating trip: $e');
      rethrow;
    }
  }

  Future<void> updateTrip(Map<String, dynamic> tripData) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) throw Exception('Failed to access trips collection');

    try {
      // Convert string id to ObjectId for MongoDB
      final String id = tripData['id'];
      tripData.remove('id');
      final objectId = ObjectId.fromHexString(id);

      // Convert DateTime timestamps to Int64 for MongoDB
      if (tripData['startDate'] != null) {
        tripData['startDate'] = Int64(tripData['startDate'] as int);
      }
      if (tripData['endDate'] != null) {
        tripData['endDate'] = Int64(tripData['endDate'] as int);
      }
      if (tripData['updatedAt'] != null) {
        tripData['updatedAt'] = Int64(tripData['updatedAt'] as int);
      }

      await trips.update(where.id(objectId), {r'$set': tripData});
    } catch (e) {
      debugPrint('Error updating trip: $e');
      rethrow;
    }
  }

  Future<void> deleteTrip(String tripId) async {
    await connect();
    final trips = collection(tripsCollection);
    if (trips == null) throw Exception('Failed to access trips collection');

    try {
      debugPrint('Attempting to delete trip with ID: $tripId');
      await trips.remove(where.eq('id', tripId));
      debugPrint('Trip deleted successfully');
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await connect();
    final expenses = collection(expensesCollection);
    if (expenses == null) {
      throw Exception('Failed to access expenses collection');
    }
    await expenses.remove(where.eq('id', expenseId));
  }

  Future<Map<String, String>> getUsersByIds(List<String> userIds) async {
    await connect();
    final users = collection(usersCollection);
    if (users == null) return {};
    final result = await users.find(where.oneFrom('uid', userIds)).toList();
    return {
      for (var user in result) user['uid'] as String: user['name'] as String,
    };
  }
}
