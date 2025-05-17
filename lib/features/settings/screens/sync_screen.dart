import 'package:flutter/material.dart';
import '../../../core/services/dual_storage_service.dart';
import '../../../core/widgets/mongodb_status_indicator.dart';
import 'dart:async';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

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
    final isSyncing = await _dualStorageService.isSyncing;
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
        title: const Text('MongoDB Sync'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MongoDB Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    const MongoDBStatusIndicator(showConnectionString: true),
                  ],
                ),
              ),
            ),

            // Sync controls
            Text(
              'Manual Synchronization',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Synchronize your local data with MongoDB. This will upload all your local trips, expenses and other data to the cloud.',
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
              'Note: Automatic syncing happens in the background when you are online and your MongoDB is configured correctly.',
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
