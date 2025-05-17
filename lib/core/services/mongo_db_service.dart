import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  static MongoDBService get instance => _instance;

  // Connection string storage key
  static const String _connectionStringKey = 'mongodb_connection_string';

  // Default local MongoDB connection (useful for development)
  static const String _defaultLocalConnection =
      'mongodb://localhost:27017/hisabkitab';

  // Default MongoDB Atlas connection template (requires user input)
  static const String _defaultAtlasTemplate =
      'mongodb+srv://<username>:<password>@<cluster>.mongodb.net/hisabkitab';

  static const String _dbName = 'hisabkitab';

  Db? _db;
  bool _isConnected = false;
  String? _connectionString;

  // Collection names
  static const String usersCollection = 'users';
  static const String tripsCollection = 'trips';
  static const String groupsCollection = 'groups';
  static const String expensesCollection = 'expenses';

  MongoDBService._internal();

  bool get isConnected => _isConnected;
  Db? get db => _db;

  // Set connection string and close any existing connection
  Future<void> setConnectionString(String connectionString) async {
    if (_isConnected) {
      await close();
    }

    _connectionString = connectionString;

    // Save connection string for future app launches
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionStringKey, connectionString);
  }

  // Get the current connection string
  Future<String> getConnectionString() async {
    if (_connectionString != null) {
      return _connectionString!;
    }

    // Try to load from preferences
    final prefs = await SharedPreferences.getInstance();
    _connectionString = prefs.getString(_connectionStringKey);

    // Use default if not found
    if (_connectionString == null || _connectionString!.isEmpty) {
      _connectionString = _defaultAtlasTemplate;
    }

    return _connectionString!;
  }

  // Check if connection string contains placeholders
  Future<bool> hasValidConnectionString() async {
    final connString = await getConnectionString();
    return !connString.contains('<username>') &&
        !connString.contains('<password>') &&
        !connString.contains('<cluster>');
  }

  // Convert mongodb+srv:// protocol to standard mongodb://
  String _normalizeConnectionString(String connectionString) {
    if (connectionString.startsWith('mongodb+srv://')) {
      // Extract components
      final uriComponents = connectionString.split('://')[1].split('@');
      final credentials = uriComponents[0];
      final hostAndDb = uriComponents[1];

      // Create standard mongodb:// URI
      return 'mongodb://$credentials@$hostAndDb?ssl=true';
    }
    return connectionString;
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      // Get the connection string
      final connString = await getConnectionString();

      // Check if connection string is valid
      if (connString.contains('<username>') ||
          connString.contains('<password>')) {
        throw Exception('MongoDB connection string has not been configured');
      }

      // Normalize the connection string to handle mongodb+srv://
      final normalizedConnString = _normalizeConnectionString(connString);

      // Create a connection
      _db = Db(normalizedConnString);

      await _db!.open();
      _isConnected = true;
      debugPrint('Connected to MongoDB successfully');
    } catch (e) {
      debugPrint('Failed to connect to MongoDB: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> close() async {
    if (_isConnected && _db != null) {
      await _db!.close();
      _isConnected = false;
      debugPrint('Closed MongoDB connection');
    }
  }

  // Get a collection by name
  DbCollection? collection(String name) {
    if (!_isConnected || _db == null) {
      debugPrint('Not connected to MongoDB');
      return null;
    }
    return _db!.collection(name);
  }

  // User methods
  Future<void> saveUser(Map<String, dynamic> user) async {
    await connect();
    final users = collection(usersCollection);
    await users?.updateOne(
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
    final result = await users?.findOne(where.eq('uid', uid));
    return result;
  }

  // Trip methods
  Future<void> saveTrip(Map<String, dynamic> trip) async {
    await connect();
    final trips = collection(tripsCollection);
    await trips?.updateOne(
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
  }

  Future<List<Map<String, dynamic>>> getTripsForUser(String userId) async {
    await connect();
    final trips = collection(tripsCollection);
    final result = await trips?.find(where.eq('members', userId)).toList();
    return result?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> deleteTrip(String tripId) async {
    await connect();
    final trips = collection(tripsCollection);
    await trips?.deleteOne(where.eq('id', tripId));
  }

  // Group methods
  Future<void> saveGroup(Map<String, dynamic> group) async {
    await connect();
    final groups = collection(groupsCollection);
    await groups?.updateOne(
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
    final result = await groups?.find(where.eq('memberIds', userId)).toList();
    return result?.cast<Map<String, dynamic>>() ?? [];
  }

  // Expense methods
  Future<void> saveExpense(Map<String, dynamic> expense) async {
    await connect();
    final expenses = collection(expensesCollection);
    await expenses?.updateOne(
      where.eq('id', expense['id']),
      modify
          .set('amount', expense['amount'])
          .set('description', expense['description'])
          .set('category', expense['category'])
          .set('date', expense['date'])
          .set('paidById', expense['paidById'])
          .set('groupId', expense['groupId'])
          .set('tripId', expense['tripId'])
          .set('splitMethod', expense['splitMethod'])
          .set('participants', expense['participants'])
          .set('createdAt', expense['createdAt'])
          .set('updatedAt', DateTime.now().millisecondsSinceEpoch),
      upsert: true,
    );
  }

  Future<List<Map<String, dynamic>>> getExpensesForTrip(String tripId) async {
    await connect();
    final expenses = collection(expensesCollection);
    final result = await expenses?.find(where.eq('tripId', tripId)).toList();
    return result?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<List<Map<String, dynamic>>> getExpensesForGroup(String groupId) async {
    await connect();
    final expenses = collection(expensesCollection);
    final result = await expenses?.find(where.eq('groupId', groupId)).toList();
    return result?.cast<Map<String, dynamic>>() ?? [];
  }

  // Test connection
  Future<bool> testConnection(String connectionString) async {
    Db? testDb;
    try {
      // Normalize the connection string to handle mongodb+srv://
      final normalizedConnString = _normalizeConnectionString(connectionString);

      testDb = Db(normalizedConnString);
      await testDb.open();
      await testDb.close();
      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      if (testDb != null) {
        await testDb.close();
      }
      return false;
    }
  }
}
