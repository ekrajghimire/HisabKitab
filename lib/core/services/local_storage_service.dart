import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/trip_model.dart';

class LocalStorageService {
  static const String _tripsKey = 'local_trips';
  static const String _userTripsMapKey = 'user_trips_map';

  // Save a trip to local storage
  static Future<bool> saveTrip(TripModel trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing trips
      List<String> tripJsonList = prefs.getStringList(_tripsKey) ?? [];

      // Convert trip to JSON string
      final tripJson = jsonEncode(trip.toMap()..['id'] = trip.id);

      // Add new trip
      tripJsonList.add(tripJson);

      // Save trips
      await prefs.setStringList(_tripsKey, tripJsonList);

      // Update user-trips mapping
      await _updateUserTripsMapping(trip);

      print('Trip saved locally: ${trip.id}');
      return true;
    } catch (e) {
      print('Error saving trip locally: $e');
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
      print('Error retrieving trips: $e');
      return [];
    }
  }

  // Retrieve trips for a specific user
  static Future<List<TripModel>> getTripsForUser(String userId) async {
    try {
      final allTrips = await getAllTrips();
      return allTrips.where((trip) => trip.members.contains(userId)).toList();
    } catch (e) {
      print('Error retrieving trips for user: $e');
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
      print('Error updating user-trips mapping: $e');
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
      print('Error deleting trip: $e');
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
      print('Error clearing trips data: $e');
    }
  }
}
