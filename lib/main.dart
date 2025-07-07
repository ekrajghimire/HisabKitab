import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/firebase_service.dart';
import 'core/services/mongo_db_service.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/groups/providers/groups_provider.dart';
import 'features/expenses/providers/expenses_provider.dart';
import 'features/groups/providers/trips_provider.dart';
import 'features/trips/screens/edit_trip_screen.dart';
import 'models/trip_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable persistence for Firebase Auth
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }

    // Initialize FirebaseService
    final firebaseService = await FirebaseService.instance;
    await firebaseService.configureFirestore();

    // Initialize MongoDB connection
    try {
      await MongoDBService.instance.connect();
    } catch (e) {
      debugPrint('MongoDB connection failed: $e');
      // Continue app execution even if MongoDB fails
      // The app will attempt to reconnect when needed
    }

    // Get theme preference - set to true for dark mode by default
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(AppConstants.darkModeKey) ?? true;

    // Create and initialize AuthProvider before app starts
    final authProvider = AuthProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => GroupsProvider()),
          ChangeNotifierProvider(create: (_) => ExpensesProvider()),
          ChangeNotifierProvider(create: (_) => TripsProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    // Fall back to a basic app in case Firebase fails to initialize
    debugPrint('Error initializing Firebase: $e');
    runApp(
      MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error initializing Firebase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/edit-trip': (context) {
          final trip = ModalRoute.of(context)!.settings.arguments as TripModel;
          return EditTripScreen(trip: trip);
        },
      },
    );
  }
}
