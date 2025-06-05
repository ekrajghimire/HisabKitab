import 'package:flutter/foundation.dart';
import '../../../models/trip_model.dart';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/firebase_service.dart';

class TripsProvider with ChangeNotifier {
  final List<TripModel> _trips = [];
  bool _isLoading = false;

  List<TripModel> get trips => [..._trips];
  bool get isLoading => _isLoading;

  Future<void> fetchTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current user ID from Firebase Auth
      final firebaseService = await FirebaseService.instance;
      final userId = firebaseService.currentUser?.uid;
      if (userId == null) throw Exception('User not signed in');

      // Fetch trips from MongoDB
      final mongoDb = MongoDBService.instance;
      final tripsData = await mongoDb.getTrips(userId);

      _trips.clear();
      _trips.addAll(tripsData.map((data) => TripModel.fromMap(data)));

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTrip(TripModel trip) async {
    try {
      final mongoDb = MongoDBService.instance;
      await mongoDb.updateTrip(trip.toMap());

      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index >= 0) {
        _trips[index] = trip;
        notifyListeners();
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> createTrip(TripModel trip) async {
    try {
      final mongoDb = MongoDBService.instance;
      await mongoDb.createTrip(trip.toMap());

      _trips.add(trip);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      final mongoDb = MongoDBService.instance;
      await mongoDb.deleteTrip(tripId);

      _trips.removeWhere((trip) => trip.id == tripId);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }
}
