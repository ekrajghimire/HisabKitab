import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/db_setup.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/providers/trips_provider.dart';

class DbSetupScreen extends StatefulWidget {
  const DbSetupScreen({super.key});

  @override
  _DbSetupScreenState createState() => _DbSetupScreenState();
}

class _DbSetupScreenState extends State<DbSetupScreen> {
  bool _isLoading = false;
  bool _isClearing = false;
  String? _resultMessage;
  bool _isError = false;

  Future<void> _resetAndSetupTripsCollection() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    if (authProvider.user == null) {
      _showResult('You must be logged in', true);
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = null;
    });

    try {
      // Get the first group ID
      await groupsProvider.fetchUserGroups(authProvider.user!.uid);
      final groups = groupsProvider.groups;

      if (groups.isEmpty) {
        _showResult('No groups found. Create a group first.', true);
        return;
      }

      // Use the first group for demonstration
      final firstGroup = groups.first;

      await DbSetup.resetAndSetupTripsCollection(
        authProvider.user!.uid,
        firstGroup.id,
      );

      _showResult('Trips collection successfully configured!', false);
    } catch (e) {
      _showResult('Error: ${e.toString()}', true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearLocalTrips() async {
    setState(() {
      _isClearing = true;
      _resultMessage = null;
    });

    try {
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      final success = await tripsProvider.clearAllTrips();

      if (success) {
        _showResult('Local trip data successfully cleared!', false);
      } else {
        _showResult('Failed to clear local trip data.', true);
      }
    } catch (e) {
      _showResult('Error: ${e.toString()}', true);
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  void _showResult(String message, bool isError) {
    setState(() {
      _resultMessage = message;
      _isError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Database Setup'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            Text(
              'Database Configuration Tools',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trips Collection Setup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Delete and recreate the trips collection with proper structure. This will remove all existing trip data.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        _isLoading ? null : _resetAndSetupTripsCollection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text('Reset & Setup Trips'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local Storage Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Clear locally stored trip data.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isClearing ? null : _clearLocalTrips,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _isClearing
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text('Clear Local Trips'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_resultMessage != null)
              Container(
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  _resultMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),

            const Spacer(),

            const Text(
              'Warning: These operations will modify your app data.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
