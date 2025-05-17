import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lib/firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('Firebase initialized successfully');

    // Test firestore connection by trying to fetch a document
    final firestore = FirebaseFirestore.instance;
    final testQuery = await firestore.collection('groups').limit(1).get();
    print('Firestore query executed successfully');
    print('Documents found: ${testQuery.docs.length}');

    // Write a test document
    final testDoc = await firestore
        .collection('test')
        .doc('test_connection')
        .set({
          'timestamp': FieldValue.serverTimestamp(),
          'message': 'Connection test successful',
        });
    print('Test document written successfully');
  } catch (e) {
    print('Firebase Error: $e');
  }
}
