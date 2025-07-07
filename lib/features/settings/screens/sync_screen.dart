import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/user_model.dart';
import '../../../models/trip_model.dart';
import '../../../models/expense_model.dart';

class SyncStatus {
  final bool isComplete;
  final String message;
  final String? details;
  final bool success;
  final double progress;

  SyncStatus({
    required this.isComplete,
    required this.message,
    this.details,
    required this.success,
    required this.progress,
  });
}

class DualStorageService {
  static final DualStorageService _instance = DualStorageService._internal();
  static DualStorageService get instance => _instance;
  final MongoDBService _mongoDb = MongoDBService.instance;

  DualStorageService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Stream<SyncStatus> manualSync() async* {
    if (_isSyncing) {
      yield SyncStatus(
        isComplete: true,
        message: 'Sync already in progress',
        success: false,
        progress: 0,
      );
      return;
    }

    _isSyncing = true;
    try {
      // Connect to MongoDB
      yield SyncStatus(
        isComplete: false,
        message: 'Connecting to MongoDB...',
        success: true,
        progress: 10,
      );
      await _mongoDb.connect();

      // Get current user
      final firebaseService = await FirebaseService.instance;
      final currentUser = firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get last sync timestamp
      final lastSync = await LocalStorageService.getLastSyncTimestamp();

      // Sync users
      yield SyncStatus(
        isComplete: false,
        message: 'Syncing user data...',
        success: true,
        progress: 30,
      );

      // Get current user data from MongoDB
      final userData = await _mongoDb.getUser(currentUser.uid);
      if (userData != null) {
        // Save to local storage
        await LocalStorageService.saveUser(UserModel.fromMap(userData));
      }

      // Sync trips
      yield SyncStatus(
        isComplete: false,
        message: 'Syncing trips...',
        success: true,
        progress: 60,
      );

      // Get trips from MongoDB
      final tripsData = await _mongoDb.getTripsForUser(currentUser.uid);

      // Save each trip to local storage
      for (final tripData in tripsData) {
        final trip = TripModel.fromMap(tripData);
        await LocalStorageService.saveTrip(trip);
      }

      // Get local trips and sync to MongoDB if newer
      final localTrips = await LocalStorageService.getAllTrips();
      for (final localTrip in localTrips) {
        final shouldSync =
            lastSync == null || localTrip.updatedAt.isAfter(lastSync);
        if (shouldSync) {
          await _mongoDb.saveTrip(localTrip.toMap());
        }
      }

      // Sync expenses
      yield SyncStatus(
        isComplete: false,
        message: 'Syncing expenses...',
        success: true,
        progress: 90,
      );

      // For each trip, sync its expenses
      for (final trip in localTrips) {
        // Get expenses from MongoDB
        final expensesData = await _mongoDb.getExpensesForGroup(trip.groupId);

        // Save MongoDB expenses locally
        for (final expenseData in expensesData) {
          final expense = ExpenseModel.fromMap(expenseData);
          await LocalStorageService.saveExpense(expense);
        }

        // Get local expenses and sync to MongoDB if newer
        final localExpenses = await LocalStorageService.getExpensesForGroup(
          trip.groupId,
        );
        for (final localExpense in localExpenses) {
          final shouldSync =
              lastSync == null || localExpense.updatedAt.isAfter(lastSync);
          if (shouldSync) {
            await _mongoDb.saveExpense(localExpense.toMap());
          }
        }
      }

      // Update last sync timestamp
      await LocalStorageService.updateLastSyncTimestamp();

      yield SyncStatus(
        isComplete: true,
        message: 'All data synchronized successfully',
        details: 'Synced ${localTrips.length} trips and their expenses',
        success: true,
        progress: 100,
      );
    } catch (e) {
      yield SyncStatus(
        isComplete: true,
        message: 'Sync failed',
        details: e.toString(),
        success: false,
        progress: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  StreamSubscription<SyncStatus>? _syncSubscription;
  SyncStatus? _lastStatus;
  final DualStorageService _dualStorageService = DualStorageService.instance;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final isSyncing = _dualStorageService.isSyncing;
    setState(() {
      _isSyncing = isSyncing;
    });
  }

  Future<void> _startSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _lastStatus = null;
    });

    _syncSubscription = _dualStorageService.manualSync().listen(
      (status) {
        setState(() {
          _lastStatus = status;
          _isSyncing = !status.isComplete;
        });
      },
      onError: (error) {
        setState(() {
          _lastStatus = SyncStatus(
            isComplete: true,
            message: 'Error: $error',
            success: false,
            progress: 0,
          );
          _isSyncing = false;
        });
      },
      onDone: () {
        setState(() {
          _isSyncing = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Data Sync'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Synchronization',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Synchronize your local data with the cloud. This will upload all your trips, expenses and other data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Sync button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _startSync,
                icon:
                    _isSyncing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Start Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Progress section
            if (_lastStatus != null) ...[
              const SizedBox(height: 32),
              Text(
                'Sync Progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              LinearProgressIndicator(
                value: _lastStatus!.progress / 100,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _lastStatus!.success ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _lastStatus!.success
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastStatus!.success ? Icons.check_circle : Icons.error,
                      color: _lastStatus!.success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastStatus!.isComplete
                                ? (_lastStatus!.success
                                    ? 'Sync Complete'
                                    : 'Sync Failed')
                                : 'Syncing...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _lastStatus!.success
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastStatus!.message,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Footer note
            Text(
              'Note: Automatic syncing happens in the background when you are online.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
