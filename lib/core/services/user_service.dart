import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache user data to avoid repeated database calls
  final Map<String, UserModel> _userCache = {};

  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Get the current authenticated user
  User? get currentUser => _auth.currentUser;

  // Get user data from cache or Firestore
  Future<UserModel?> getUserData(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .get();

      if (doc.exists) {
        final userData = UserModel.fromMap(doc.data()!..['id'] = doc.id);
        // Add to cache
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return null;
  }

  // Get multiple users' data at once
  Future<Map<String, UserModel>> getUsersData(List<String> userIds) async {
    final Map<String, UserModel> users = {};
    final List<String> usersToFetch = [];

    // Check cache first
    for (final userId in userIds) {
      if (_userCache.containsKey(userId)) {
        users[userId] = _userCache[userId]!;
      } else {
        usersToFetch.add(userId);
      }
    }

    if (usersToFetch.isEmpty) {
      return users;
    }

    try {
      // Batch get users that aren't in cache
      final querySnapshot =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where(FieldPath.documentId, whereIn: usersToFetch)
              .get();

      for (final doc in querySnapshot.docs) {
        final userData = UserModel.fromMap(doc.data()..['id'] = doc.id);
        users[doc.id] = userData;
        _userCache[doc.id] = userData; // Update cache
      }
    } catch (e) {
      print('Error fetching multiple users: $e');
    }

    return users;
  }

  // Update user data
  Future<bool> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .update(user.toMap());

      // Update cache
      _userCache[user.id] = user;
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // Clear cache for testing or when needed
  void clearCache() {
    _userCache.clear();
  }

  // Clear specific user from cache
  void removeFromCache(String userId) {
    _userCache.remove(userId);
  }

  // Get user display name (with cache)
  Future<String> getUserDisplayName(String userId) async {
    final user = await getUserData(userId);
    return user?.name ?? 'Unknown User';
  }

  // Check if a user ID is the current user
  bool isCurrentUser(String userId) {
    return currentUser?.uid == userId;
  }
}
