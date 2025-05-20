import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/trip_model.dart';
import '../../../core/services/dual_storage_service.dart';

class TripsProvider with ChangeNotifier {
  List<TripModel> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

  final DualStorageService _storage = DualStorageService.instance;

  List<TripModel> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch trips for a user
  Future<void> fetchUserTrips(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('Fetching trips for user: $userId');

      // Get trips using dual storage service which handles both local and MongoDB sources
      final userTrips = await _storage.getTripsForUser(userId);

      print('Trips fetched: ${userTrips.length}');

      _trips = userTrips;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching trips: $e');
      _isLoading = false;
      _errorMessage = 'Failed to fetch trips: ${e.toString()}';
      notifyListeners();
    }
  }

  // Create new trip
  Future<TripModel?> createTrip({
    required String name,
    required String description,
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

      print(
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

      // Print the trip data before saving
      print('Trip data: ${newTrip.toMap()}');

      // Save using dual storage service which handles both local and MongoDB storage
      final success = await _storage.saveTrip(newTrip);

      if (!success) {
        throw Exception('Failed to save trip');
      }

      print('Trip saved successfully with ID: $tripId');

      // Add to local list
      _trips.add(newTrip);
      _isLoading = false;
      notifyListeners();

      print('Local state updated with new trip');

      return newTrip;
    } catch (e) {
      print('ERROR creating trip: $e');
      _isLoading = false;
      _errorMessage = 'Failed to create trip: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Clear all trips (for testing)
  Future<bool> clearAllTrips() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _storage.clearAllTripsData();

      _trips = [];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error clearing trips: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Manual sync with MongoDB (can be called from settings)
  Future<bool> syncWithMongoDB() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _storage.syncWithMongoDB();

      // Refresh trips after sync
      if (success && _trips.isNotEmpty && _trips.first.createdBy.isNotEmpty) {
        await fetchUserTrips(_trips.first.createdBy);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('Error syncing with MongoDB: $e');
      _isLoading = false;
      _errorMessage = 'Failed to sync with MongoDB: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
