import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  static MongoDBService get instance => _instance;

  // Replace with your actual MongoDB Atlas connection string
  static const String _connectionString =
      'mongodb+srv://hisabkitabdb:hisabkitabpassword@hisabkitabcluster.vanbrth.mongodb.net/hisabkitab?retryWrites=true&w=majority';
  Db? _db;
  bool _isConnected = false;
  bool _isOnline = true;

  // Collection names
  static const String usersCollection = 'users';
  static const String tripsCollection = 'trips';
  static const String groupsCollection = 'groups';
  static const String expensesCollection = 'expenses';

  MongoDBService._internal() {
    // Initialize connectivity listener
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline && !_isConnected) {
        _connectInBackground(); // Try to reconnect when back online
      }
    });

    // Start initial connection attempt in background
    _connectInBackground();
  }

  bool get isConnected => _isConnected;
  bool get isOnline => _isOnline;
  Db? get db => _db;

  Future<void> connect() async {
    if (_isConnected || !_isOnline) return;

    try {
      debugPrint('MongoDBService: Attempting to connect...');

      // Add timeout to prevent long blocking
      await _connectWithTimeout();

      _isConnected = true;
      debugPrint('MongoDBService: Connected successfully');

      // Verify connection by listing collections (with timeout)
      try {
        await _verifyConnectionWithTimeout();
      } catch (e) {
        debugPrint('MongoDBService: Collection verification failed: $e');
      }

      // Create indexes if needed (non-blocking)
      _createIndexesInBackground();
    } catch (e, stackTrace) {
      _isConnected = false;
      _db = null; // Clear the DB instance on connection failure
      debugPrint(
        'MongoDBService: Failed to connect: $e\nStackTrace: $stackTrace',
      );
      // Don't rethrow - allow offline operation
    }
  }

  Future<void> _connectWithTimeout() async {
    await Future.any([
      () async {
        _db = await Db.create(_connectionString);
        await _db!.open();
      }(),
      Future.delayed(Duration(seconds: 10)).then((_) {
        throw TimeoutException('Connection timeout', Duration(seconds: 10));
      }),
    ]);
  }

  Future<void> _verifyConnectionWithTimeout() async {
    await Future.any([
      () async {
        final collections = await _db!.getCollectionNames();
        debugPrint('MongoDBService: Available collections: $collections');
      }(),
      Future.delayed(Duration(seconds: 5)).then((_) {
        throw TimeoutException('Verification timeout', Duration(seconds: 5));
      }),
    ]);
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

  // Non-blocking index creation
  void _createIndexesInBackground() {
    _createIndexes().catchError((error) {
      debugPrint('Background index creation failed: $error');
    });
  }

  Future<void> close() async {
    if (_isConnected && _db != null) {
      await _db!.close();
      _isConnected = false;
      _db = null; // Clear the DB instance when closing
      debugPrint('MongoDBService: Connection closed');
    }
  }

  DbCollection? collection(String name) {
    if (!_isOnline) {
      debugPrint('MongoDBService: Device is offline');
      return null;
    }

    if (!_isConnected || _db == null) {
      debugPrint('MongoDBService: Not connected. Attempting to reconnect...');
      // Don't wait for connect() to complete - return null immediately
      connect();
      return null;
    }

    try {
      // Check if the database is still active
      if (_db!.state != State.open) {
        debugPrint('MongoDBService: Database state is not open: ${_db!.state}');
        _isConnected = false;
        _db = null;
        connect();
        return null;
      }
      return _db!.collection(name);
    } catch (e) {
      debugPrint('MongoDBService: Error accessing collection: $e');
      _isConnected = false;
      _db = null;
      return null;
    }
  }

  // User methods
  Future<void> saveUser(Map<String, dynamic> user) async {
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, skipping saveUser');
      throw Exception('Not connected to MongoDB');
    }

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
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, skipping getUser');
      return null;
    }

    final users = collection(usersCollection);
    if (users == null) return null;

    try {
      return await users.findOne(where.eq('uid', uid));
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  // Trip methods
  Future<void> saveTrip(Map<String, dynamic> trip) async {
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, skipping saveTrip');
      throw Exception('Not connected to MongoDB');
    }

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
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, returning empty list');
      return [];
    }

    final trips = collection(tripsCollection);
    if (trips == null) return [];

    try {
      final result =
          await trips.find(where.eq('members', userId)).map((doc) {
            // Ensure the _id is converted to a string id
            final Map<String, dynamic> map = {...doc};
            map['id'] = doc['_id'].toHexString();
            map.remove('_id');

            // Convert Int64 timestamps to regular integers if they exist
            if (doc['startDate'] is Int64) {
              map['startDate'] = (doc['startDate'] as Int64).toInt();
            }
            if (doc['endDate'] is Int64) {
              map['endDate'] = (doc['endDate'] as Int64).toInt();
            }
            if (doc['createdAt'] is Int64) {
              map['createdAt'] = (doc['createdAt'] as Int64).toInt();
            }
            if (doc['updatedAt'] is Int64) {
              map['updatedAt'] = (doc['updatedAt'] as Int64).toInt();
            }

            return map;
          }).toList();
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching trips for user: $e');
      return [];
    }
  }

  // Group methods
  Future<void> saveGroup(Map<String, dynamic> group) async {
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, skipping saveGroup');
      throw Exception('Not connected to MongoDB');
    }

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
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, returning empty list');
      return [];
    }

    final groups = collection(groupsCollection);
    if (groups == null) return [];

    try {
      final result = await groups.find(where.eq('memberIds', userId)).toList();
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching groups for user: $e');
      return [];
    }
  }

  Future<void> deleteGroup(String groupId) async {
    // Don't wait for connection - fail fast if not connected
    if (!_isConnected) {
      debugPrint('MongoDBService: Not connected, skipping deleteGroup');
      throw Exception('Not connected to MongoDB');
    }

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
    // Try to fetch by 'uid' first
    var result = await users.find(where.oneFrom('uid', userIds)).toList();
    if (result.isEmpty) {
      // If nothing found, try by '_id' (ObjectId)
      try {
        final objectIds = userIds.map((id) => ObjectId.parse(id)).toList();
        result = await users.find(where.oneFrom('_id', objectIds)).toList();
        return {
          for (var user in result)
            user['_id'].toHexString(): user['name'] as String,
        };
      } catch (e) {
        // If parsing fails, just return empty
        return {};
      }
    }
    return {
      for (var user in result) user['uid'] as String: user['name'] as String,
    };
  }

  // Non-blocking background connection
  void _connectInBackground() {
    if (_isConnected || !_isOnline) return;

    // Connect in background without blocking
    connect().catchError((error) {
      debugPrint('Background connection failed: $error');
    });
  }
}
