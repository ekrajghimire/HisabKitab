import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import './mongo_db_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/trip_model.dart';

/// Service that synchronizes data between local storage and MongoDB
class DualStorageService {
  static const String _tripsKey = 'local_trips';
  static const String _userTripsMapKey = 'user_trips_map';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _isSyncingKey = 'is_syncing';

  final MongoDBService _mongoService = MongoDBService.instance;

  // Singleton instance
  static final DualStorageService _instance = DualStorageService._internal();
  static DualStorageService get instance => _instance;
  DualStorageService._internal();

  // Check if device is online with MongoDB connected
  Future<bool> get isOnline async {
    try {
      await _mongoService.connect();
      return _mongoService.isConnected;
    } catch (e) {
      debugPrint('MongoDB connection check failed: $e');
      return false;
    }
  }

  // Check if sync is in progress
  Future<bool> get isSyncing async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSyncingKey) ?? false;
  }

  // Set syncing status
  Future<void> _setSyncingStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isSyncingKey, status);
  }

  // Record last sync time
  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<int?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncKey);
  }

  // TRIPS

  // Save a trip to both local storage and MongoDB if online
  Future<bool> saveTrip(TripModel trip) async {
    try {
      // Step 1: Save locally first (always)
      await _saveLocalTrip(trip);

      // Step 2: Try to save to MongoDB if online
      final bool isConnected = await isOnline;
      if (isConnected) {
        await _mongoService.saveTrip(trip.toMap()..['id'] = trip.id);
        await _updateLastSyncTime();
      }

      debugPrint('Trip saved: ${trip.id} (MongoDB: $isConnected)');
      return true;
    } catch (e) {
      debugPrint('Error saving trip: $e');
      return false;
    }
  }

  // Save a trip to local storage only
  Future<bool> _saveLocalTrip(TripModel trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing trips
      List<String> tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      // Remove existing trip with same ID if it exists
      tripJsonList =
          tripJsonList.where((tripJson) {
            Map<String, dynamic> tripMap = jsonDecode(tripJson);
            return tripMap['id'] != trip.id;
          }).toList();

      // Convert trip to JSON string and add
      final tripJson = jsonEncode(trip.toMap()..['id'] = trip.id);
      tripJsonList.add(tripJson);

      // Save trips
      await prefs.setStringList(_tripsKey, tripJsonList);

      // Update user-trips mapping
      await _updateUserTripsMapping(trip);

      return true;
    } catch (e) {
      debugPrint('Error saving trip locally: $e');
      return false;
    }
  }

  // Update the user-trips mapping
  Future<void> _updateUserTripsMapping(TripModel trip) async {
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

  // Retrieve all trips from local storage
  Future<List<TripModel>> getAllLocalTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      return tripJsonList.map((tripJson) {
        Map<String, dynamic> tripMap = jsonDecode(tripJson);
        return TripModel.fromMap(tripMap);
      }).toList();
    } catch (e) {
      debugPrint('Error retrieving local trips: $e');
      return [];
    }
  }

  // Retrieve trips for a specific user from both sources
  Future<List<TripModel>> getTripsForUser(String userId) async {
    List<TripModel> trips = [];

    // First, get local trips
    trips = await getLocalTripsForUser(userId);

    // Try to sync with MongoDB if online
    final bool isConnected = await isOnline;
    if (isConnected) {
      try {
        // Get remote trips
        final List<Map<String, dynamic>> remoteTrips = await _mongoService
            .getTripsForUser(userId);

        // Convert to TripModel objects
        final List<TripModel> remoteModels =
            remoteTrips.map((map) => TripModel.fromMap(map)).toList();

        // Merge local and remote trips, prioritizing remote versions
        // by adding them to a map keyed by ID
        final Map<String, TripModel> mergedTrips = {};

        // Add local trips first
        for (var trip in trips) {
          mergedTrips[trip.id] = trip;
        }

        // Add/replace with remote trips
        for (var trip in remoteModels) {
          mergedTrips[trip.id] = trip;
          // Also update local storage with remote version
          await _saveLocalTrip(trip);
        }

        // Extract combined list
        trips = mergedTrips.values.toList();

        // Update the last sync time
        await _updateLastSyncTime();
      } catch (e) {
        debugPrint('Error syncing with MongoDB: $e');
        // If there's an error syncing, we'll just use the local trips
      }
    }

    // Sort by start date (descending)
    trips.sort((a, b) => b.startDate.compareTo(a.startDate));

    return trips;
  }

  // Retrieve trips for a specific user from local storage only
  Future<List<TripModel>> getLocalTripsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get user's trip IDs from mapping
      String mapJson = prefs.getString(_userTripsMapKey) ?? '{}';
      Map<String, dynamic> userTripsMap = jsonDecode(mapJson);
      List<String> userTripIds = List<String>.from(userTripsMap[userId] ?? []);

      // Get all trips
      final allTrips = await getAllLocalTrips();

      // Filter to just the user's trips
      return allTrips.where((trip) => userTripIds.contains(trip.id)).toList();
    } catch (e) {
      debugPrint('Error retrieving trips for user: $e');
      return [];
    }
  }

  // Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    try {
      // Delete locally
      final prefs = await SharedPreferences.getInstance();
      List<String> tripJsonList = prefs.getStringList(_tripsKey) ?? [];
      tripJsonList =
          tripJsonList.where((tripJson) {
            Map<String, dynamic> tripMap = jsonDecode(tripJson);
            return tripMap['id'] != tripId;
          }).toList();
      await prefs.setStringList(_tripsKey, tripJsonList);

      // Try to delete from MongoDB if online
      final bool isConnected = await isOnline;
      if (isConnected) {
        await _mongoService.deleteTrip(tripId);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      return false;
    }
  }

  // Clear all trips data (for testing)
  Future<void> clearAllTripsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tripsKey);
      await prefs.remove(_userTripsMapKey);

      // No need to clear MongoDB as this is just for testing
    } catch (e) {
      debugPrint('Error clearing trips data: $e');
    }
  }

  // Synchronize local data with MongoDB
  Future<bool> syncWithMongoDB() async {
    try {
      final bool isConnected = await isOnline;
      if (!isConnected) {
        return false;
      }

      // Get all local trips
      final allTrips = await getAllLocalTrips();

      // Push each trip to MongoDB
      for (var trip in allTrips) {
        await _mongoService.saveTrip(trip.toMap()..['id'] = trip.id);
      }

      // Update sync timestamp
      await _updateLastSyncTime();
      return true;
    } catch (e) {
      debugPrint('Error syncing with MongoDB: $e');
      return false;
    }
  }

  /// Manually trigger synchronization with MongoDB
  /// Returns a stream of sync status updates
  Stream<SyncStatus> manualSync() async* {
    // Check if already syncing
    if (await isSyncing) {
      yield SyncStatus(
        isComplete: false,
        message: 'Sync already in progress',
        success: false,
        progress: 0,
      );
      return;
    }

    try {
      // Set syncing flag
      await _setSyncingStatus(true);

      // Check connection
      yield SyncStatus(
        isComplete: false,
        message: 'Checking connection...',
        success: true,
        progress: 10,
      );

      final isConnected = await isOnline;
      if (!isConnected) {
        yield SyncStatus(
          isComplete: true,
          message:
              'MongoDB connection failed. Please check your configuration.',
          success: false,
          progress: 0,
        );
        await _setSyncingStatus(false);
        return;
      }

      // Get all local trips
      yield SyncStatus(
        isComplete: false,
        message: 'Reading local data...',
        success: true,
        progress: 30,
      );

      final allTrips = await getAllLocalTrips();

      // Push local data to MongoDB
      yield SyncStatus(
        isComplete: false,
        message: 'Uploading data to MongoDB...',
        success: true,
        progress: 50,
      );

      int processed = 0;
      final totalItems = allTrips.length;

      // Push each trip to MongoDB
      for (var trip in allTrips) {
        await _mongoService.saveTrip(trip.toMap()..['id'] = trip.id);
        processed++;

        final progress = 50 + ((processed / totalItems) * 40);
        yield SyncStatus(
          isComplete: false,
          message: 'Syncing trip $processed/$totalItems...',
          success: true,
          progress: progress.toInt(),
        );
      }

      // Update sync timestamp
      yield SyncStatus(
        isComplete: false,
        message: 'Finalizing sync...',
        success: true,
        progress: 95,
      );

      await _updateLastSyncTime();

      // Complete
      yield SyncStatus(
        isComplete: true,
        message: 'Sync completed successfully!',
        success: true,
        progress: 100,
      );
    } catch (e) {
      yield SyncStatus(
        isComplete: true,
        message: 'Error during sync: ${e.toString()}',
        success: false,
        progress: 0,
      );
    } finally {
      await _setSyncingStatus(false);
    }
  }
}

/// Class to represent synchronization status
class SyncStatus {
  final bool isComplete;
  final String message;
  final bool success;
  final int progress; // 0-100

  SyncStatus({
    required this.isComplete,
    required this.message,
    required this.success,
    required this.progress,
  });
}
