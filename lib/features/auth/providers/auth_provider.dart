import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/user_model.dart';
import '../../../core/services/mongo_db_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final MongoDBService _mongoDb = MongoDBService.instance;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  UserModel? _userModel;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    // Initialize by checking persistent auth state
    _initAuthState();

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _fetchUserData();
        _status = AuthStatus.authenticated;
        _saveAuthState(true);
      } else {
        _userModel = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  // Initialize auth state from SharedPreferences
  Future<void> _initAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.userLoggedInKey) ?? false;

      // If user was previously logged in but Firebase doesn't have current user
      // (e.g., app was force closed), try to restore the session
      if (isLoggedIn && _auth.currentUser == null) {
        _status = AuthStatus.loading;
        notifyListeners();

        // Wait for Firebase to initialize and check again
        await Future.delayed(const Duration(seconds: 1));

        // If Firebase auth still doesn't have a user but we have a saved state,
        // we need to clear the saved state as it's out of sync
        if (_auth.currentUser == null) {
          await prefs.setBool(AppConstants.userLoggedInKey, false);
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error initializing auth state: $e');
    }
  }

  // Save auth state to SharedPreferences
  Future<void> _saveAuthState(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.userLoggedInKey, isLoggedIn);
      if (isLoggedIn && _user != null) {
        await prefs.setString(AppConstants.userIdKey, _user!.uid);
      } else {
        await prefs.remove(AppConstants.userIdKey);
      }
    } catch (e) {
      debugPrint('Error saving auth state: $e');
    }
  }

  Future<void> _fetchUserData() async {
    if (_user != null) {
      try {
        final doc =
            await _firestore
                .collection(AppConstants.usersCollection)
                .doc(_user!.uid)
                .get();

        if (doc.exists) {
          _userModel = UserModel.fromMap(doc.data()!..['id'] = doc.id);
        }
      } catch (e) {
        _errorMessage = 'Failed to fetch user data: ${e.toString()}';
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _saveAuthState(true);
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getMessageFromErrorCode(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        final doc =
            await _firestore
                .collection(AppConstants.usersCollection)
                .doc(user.uid)
                .get();

        if (!doc.exists) {
          final now = DateTime.now();
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            createdAt: now,
            updatedAt: now,
          );

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .set(newUser.toMap());
        }

        await _saveAuthState(true);
        return true;
      }

      _status = AuthStatus.unauthenticated;
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getMessageFromErrorCode(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        final now = DateTime.now();
        final newUser = UserModel(
          uid: result.user!.uid,
          name: name,
          email: email.trim(),
          photoUrl: null,
          createdAt: now,
          updatedAt: now,
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(result.user!.uid)
            .set(newUser.toMap());

        _userModel = newUser;

        await _saveAuthState(true);
        return true;
      }

      _status = AuthStatus.unauthenticated;
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getMessageFromErrorCode(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      // Sign out from Google as well if it was used
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      await _saveAuthState(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign out: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email.trim());

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getMessageFromErrorCode(e);
      notifyListeners();
      return false;
    }
  }

  String _getMessageFromErrorCode(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The email address is already in use.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address but different sign-in credentials.';
        default:
          return 'Authentication error: ${error.message}';
      }
    }
    return 'An error occurred: ${error.toString()}';
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      final users =
          await _mongoDb
              .collection(MongoDBService.usersCollection)
              ?.find({
                '_id': {r'$in': userIds},
              })
              .map((doc) {
                final map = {...doc};
                map['uid'] = doc['_id'].toString();
                map.remove('_id');
                return UserModel.fromMap(map);
              })
              .toList();

      return users?.cast<UserModel>() ?? [];
    } catch (e) {
      debugPrint('Error fetching users: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final users =
          await _mongoDb
              .collection(MongoDBService.usersCollection)
              ?.find({
                r'$or': [
                  {
                    'name': {r'$regex': query, r'$options': 'i'},
                  },
                  {
                    'email': {r'$regex': query, r'$options': 'i'},
                  },
                ],
              })
              .map((doc) {
                final map = {...doc};
                map['uid'] = doc['_id'].toString();
                map.remove('_id');
                return UserModel.fromMap(map);
              })
              .toList();

      return users?.cast<UserModel>() ?? [];
    } catch (e) {
      debugPrint('Error searching users: $e');
      rethrow;
    }
  }
}
