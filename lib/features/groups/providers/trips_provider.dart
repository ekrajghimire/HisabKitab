import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/trip_model.dart';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TripsProvider with ChangeNotifier {
  List<TripModel> _trips = [];
  bool _isLoading = false;
  bool _isOnline = true;
  String? _errorMessage;
  final Set<String> _savingToMongo = {}; // Track items being saved

  final MongoDBService _mongoDb = MongoDBService.instance;

  List<TripModel> get trips => _trips;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get errorMessage => _errorMessage;

  TripsProvider() {
    // Initialize connectivity listener
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      // If we just came back online, trigger a sync
      if (!wasOnline && _isOnline) {
        _syncTrips();
      }
      notifyListeners();
    });

    // Load any existing local data on startup
    _loadLocalData();
  }

  // Load local data on startup
  Future<void> _loadLocalData() async {
    try {
      final localTrips = await LocalStorageService.getAllTrips();
      if (localTrips.isNotEmpty) {
        _trips = localTrips;
        // Sort by created date (descending) - newest trips first
        _trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        debugPrint(
          'Loaded ${localTrips.length} trips from local storage on startup',
        );
      }
    } catch (e) {
      debugPrint('Error loading local trips on startup: $e');
    }
  }

  // Fetch trips for a user
  Future<void> fetchUserTrips(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Fetching trips for user: $userId');

      // Always start with local data
      List<TripModel> localTrips = await LocalStorageService.getTripsForUser(
        userId,
      );
      debugPrint('Found ${localTrips.length} trips in local storage');

      // Try to fetch from MongoDB if online to sync any new data
      if (_isOnline && _mongoDb.isConnected) {
        try {
          final mongoTrips = await _mongoDb.getTripsForUser(userId);
          final fetchedTrips =
              mongoTrips.map((map) => TripModel.fromMap(map)).toList();
          debugPrint('Found ${fetchedTrips.length} trips in MongoDB');

          // Merge MongoDB trips with local trips
          for (final mongoTrip in fetchedTrips) {
            final existingIndex = localTrips.indexWhere(
              (t) => t.id == mongoTrip.id,
            );
            if (existingIndex >= 0) {
              // Update existing trip if MongoDB version is newer
              if (mongoTrip.updatedAt.isAfter(
                localTrips[existingIndex].updatedAt,
              )) {
                localTrips[existingIndex] = mongoTrip;
                await LocalStorageService.saveTrip(mongoTrip);
              }
            } else {
              // Add new trip from MongoDB
              localTrips.add(mongoTrip);
              await LocalStorageService.saveTrip(mongoTrip);
            }
          }
        } catch (e) {
          debugPrint('Failed to fetch from MongoDB: $e');
          // Continue with local data only
        }
      } else {
        debugPrint('Offline mode - using local storage only');
      }

      _trips = localTrips;

      // Sort by created date (descending) - newest trips first
      _trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _isLoading = false;
      notifyListeners();
      debugPrint('Final trip count: ${_trips.length}');
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      _isLoading = false;
      _errorMessage = 'Failed to fetch trips: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _syncTrips() async {
    if (!_isOnline) return;

    try {
      // Implementation similar to the main TripsProvider
      debugPrint('Syncing trips...');
      // Add sync logic here if needed
    } catch (e) {
      debugPrint('Error during trip sync: $e');
    }
  }

  // Create new trip
  Future<TripModel?> createTrip({
    required String name,
    String description = '',
    required String groupId,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    required String currency,
    required List<String> members,
    String? icon,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint(
        'Creating trip with name: $name, group: $groupId, creator: $createdBy',
      );

      final tripId = const Uuid().v4();
      final now = DateTime.now();

      final newTrip = TripModel(
        id: tripId,
        name: name,
        description: description,
        groupId: groupId,
        createdBy: createdBy,
        startDate: startDate,
        endDate: endDate,
        currency: currency,
        members: members,
        createdAt: now,
        updatedAt: now,
        icon: icon ?? 'luggage',
      );

      // Always save to local storage first - this is fast
      await LocalStorageService.saveTrip(newTrip);

      // Add to local list immediately for instant UI update (at beginning for LIFO)
      _trips.insert(0, newTrip);
      _isLoading = false;
      notifyListeners();

      // Try to save to MongoDB in background - don't block UI
      if (_isOnline && _mongoDb.isConnected) {
        _saveToMongoInBackground(newTrip);
      } else {
        debugPrint('Offline or not connected - queueing for sync');
        // Queue for later sync when offline or not connected
        await LocalStorageService.markForSync(newTrip.id, 'trips');
      }

      debugPrint('Trip created successfully with ID: $tripId');
      return newTrip;
    } catch (e) {
      debugPrint('ERROR creating trip: $e');
      _isLoading = false;
      _errorMessage = 'Failed to create trip: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Background save to MongoDB - non-blocking
  void _saveToMongoInBackground(TripModel trip) async {
    // Prevent duplicate saves
    if (_savingToMongo.contains(trip.id)) {
      debugPrint('Trip ${trip.id} already being saved to MongoDB');
      return;
    }

    _savingToMongo.add(trip.id);
    try {
      await _mongoDb.saveTrip(trip.toMap());
      debugPrint('Trip saved to MongoDB successfully in background');
    } catch (e) {
      debugPrint('Failed to save to MongoDB in background: $e');
      // Queue for later sync
      await LocalStorageService.markForSync(trip.id, 'trips');
    } finally {
      _savingToMongo.remove(trip.id);
    }
  }

  // Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Attempting to delete trip: $tripId');

      // Delete from local storage first
      await LocalStorageService.deleteTrip(tripId);

      // Try to delete from MongoDB if online
      if (_isOnline && _mongoDb.isConnected) {
        try {
          await _mongoDb.deleteTrip(tripId);
          debugPrint('MongoDB deletion successful');
        } catch (e) {
          debugPrint('Failed to delete from MongoDB: $e');
          // Continue since we deleted local copy
        }
      }

      _trips.removeWhere((trip) => trip.id == tripId);
      debugPrint('Trip removed from local state');

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      _isLoading = false;
      _errorMessage = 'Failed to delete trip: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Clear all trips
  Future<bool> clearAllTrips() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Clear local storage
      await LocalStorageService.clearAllTripsData();

      // Clear in-memory trips
      _trips.clear();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing trips: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update an existing trip
  Future<bool> updateTrip(TripModel updatedTrip) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Save to local storage first
      await LocalStorageService.saveTrip(updatedTrip);

      // Update in-memory list
      final index = _trips.indexWhere((t) => t.id == updatedTrip.id);
      if (index != -1) {
        _trips[index] = updatedTrip;
      }

      _isLoading = false;
      notifyListeners();

      // Try to save to MongoDB in background
      if (_isOnline && _mongoDb.isConnected) {
        _saveToMongoInBackground(updatedTrip);
      } else {
        // Queue for later sync when offline or not connected
        await LocalStorageService.markForSync(updatedTrip.id, 'trips');
      }

      return true;
    } catch (e) {
      debugPrint('ERROR updating trip: $e');
      _isLoading = false;
      _errorMessage = 'Failed to update trip: e.toString()';
      notifyListeners();
      return false;
    }
  }
}
