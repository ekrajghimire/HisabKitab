import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/trip_model.dart';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/local_storage_service.dart';

class TripsProvider with ChangeNotifier {
  List<TripModel> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

  final MongoDBService _mongoDb = MongoDBService.instance;

  List<TripModel> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch trips for a user
  Future<void> fetchUserTrips(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Fetching trips for user: $userId');

      final userTrips = await _mongoDb.getTripsForUser(userId);
      _trips = userTrips.map((map) => TripModel.fromMap(map)).toList();

      // Sort by start date (descending)
      _trips.sort((a, b) => b.startDate.compareTo(a.startDate));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching trips: $e');
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

      // Save to MongoDB
      await _mongoDb.saveTrip(newTrip.toMap()..['id'] = tripId);

      // Add to local list
      _trips.add(newTrip);
      _isLoading = false;
      notifyListeners();

      debugPrint('Trip saved successfully with ID: $tripId');
      return newTrip;
    } catch (e) {
      debugPrint('ERROR creating trip: $e');
      _isLoading = false;
      _errorMessage = 'Failed to create trip: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Attempting to delete trip: $tripId');
      await _mongoDb.deleteTrip(tripId);
      debugPrint('MongoDB deletion successful');

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
}
