import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class DbSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Firebase if needed
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Clear existing trips collection
  static Future<void> clearTripsCollection() async {
    final tripsRef = _firestore.collection('trips');
    final snapshot = await tripsRef.get();

    debugPrint('Deleting existing trips...');

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
      debugPrint('Deleted ${snapshot.docs.length} trip documents');
    } else {
      debugPrint('No existing trip documents found');
    }
  }

  // Set up trips collection
  static Future<void> setupTripsCollection(
    String userId,
    String groupId,
  ) async {
    final tripsRef = _firestore.collection('trips');

    // Create a sample trip
    final sampleTrip = {
      'name': 'Sample Trip',
      'description': 'This is a sample trip to demonstrate the structure',
      'groupId': groupId,
      'createdBy': userId,
      'startDate': Timestamp.fromDate(DateTime.now()),
      'endDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
      'currency': 'INR',
      'members': [userId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await tripsRef.add(sampleTrip);
    debugPrint('Created sample trip document');
  }

  // Reset and set up trips collection
  static Future<void> resetAndSetupTripsCollection(
    String userId,
    String groupId,
  ) async {
    try {
      await clearTripsCollection();
      await setupTripsCollection(userId, groupId);
      debugPrint('Trip collection setup completed successfully');
    } catch (e) {
      debugPrint('Error setting up trips collection: $e');
      rethrow;
    }
  }
}
