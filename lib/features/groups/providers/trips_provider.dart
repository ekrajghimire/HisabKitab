import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/trip_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_storage_service.dart';

class TripsProvider with ChangeNotifier {
  List<TripModel> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

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

      // Get trips from local storage
      final localTrips = await LocalStorageService.getTripsForUser(userId);

      print('Trips fetched from local storage: ${localTrips.length}');

      // Sort by start date (descending)
      localTrips.sort((a, b) => b.startDate.compareTo(a.startDate));

      _trips = localTrips;
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
      );

      // Print the trip data before saving
      print('Trip data: ${newTrip.toMap()}');

      // Save to local storage instead of Firestore
      final success = await LocalStorageService.saveTrip(newTrip);

      if (!success) {
        throw Exception('Failed to save trip to local storage');
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

      await LocalStorageService.clearAllTripsData();

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
}
