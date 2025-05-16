import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';

/// A service class to handle Firebase initialization and provide access to Firebase services.
class FirebaseService {
  static FirebaseService? _instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  FirebaseService._({
    required this.auth,
    required this.firestore,
    required this.storage,
  });

  /// Initialize Firebase and return a singleton instance of FirebaseService.
  static Future<FirebaseService> get instance async {
    if (_instance != null) return _instance!;

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _instance = FirebaseService._(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );

    return _instance!;
  }

  /// Configure Firestore settings (optional).
  Future<void> configureFirestore() async {
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Enable offline persistence for Firestore.
  Future<void> enableOfflinePersistence() async {
    await firestore.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
  }

  /// Get the current authenticated user.
  User? get currentUser => auth.currentUser;

  /// Check if a user is currently signed in.
  bool get isUserSignedIn => auth.currentUser != null;

  /// Sign out the current user.
  Future<void> signOut() async {
    await auth.signOut();
  }
}
