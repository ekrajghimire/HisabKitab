import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/trip_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import 'create_trip_screen.dart';
import '../../trips/screens/trip_detail_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedTripIds = {};

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrips();
    });
  }

  Future<void> _loadTrips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);

    if (authProvider.user != null) {
      await tripsProvider.fetchUserTrips(authProvider.user!.uid);
    }
  }

  Future<void> _refreshTrips() async {
    await _loadTrips();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTripIds.clear();
      }
    });
  }

  void _toggleTripSelection(String tripId) {
    setState(() {
      if (_selectedTripIds.contains(tripId)) {
        _selectedTripIds.remove(tripId);
      } else {
        _selectedTripIds.add(tripId);
      }
    });
  }

  Future<void> _deleteSelectedTrips() async {
    if (_selectedTripIds.isEmpty) return;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Theme.of(context).dialogBackgroundColor,
                title: Text(
                  'Delete Selected Trips',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete ${_selectedTripIds.length} selected trip(s)? This will also delete all associated expenses.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    try {
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      int successCount = 0;
      List<String> failedTrips = [];

      for (final tripId in _selectedTripIds) {
        final success = await tripsProvider.deleteTrip(tripId);
        if (success) {
          successCount++;
        } else {
          failedTrips.add(tripId);
        }
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount trip(s) deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (failedTrips.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete ${failedTrips.length} trip(s)'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        setState(() {
          _isSelectionMode = false;
          _selectedTripIds.clear();
        });
        _refreshTrips();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting trips: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text('My Trips'),
        actions: [
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.delete_outline,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _toggleSelectionMode,
          ),
          if (_isSelectionMode && _selectedTripIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelectedTrips,
            ),
          if (!_isSelectionMode)
            IconButton(icon: Icon(Icons.refresh), onPressed: _refreshTrips),
        ],
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, child) {
          if (tripsProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          final trips = tripsProvider.trips;

          if (trips.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: _refreshTrips,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _buildTripCard(trip);
              },
            ),
          );
        },
      ),
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  ).then((_) => _refreshTrips());
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_travel,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create your first trip to start tracking expenses',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTripScreen()),
              ).then((_) => _refreshTrips());
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(TripModel trip) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedTripIds.contains(trip.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color:
          isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : (isDarkMode
                  ? Colors.grey.shade900
                  : Theme.of(context).colorScheme.surface),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isSelectionMode) {
            _toggleTripSelection(trip.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailScreen(trip: trip),
              ),
            ).then((_) => _refreshTrips());
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode();
            _toggleTripSelection(trip.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      Icons.card_travel,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              trip.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_isSelectionMode)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.members.length} travelers',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.startDate != null
                        ? _formatDate(trip.startDate)
                        : 'No date set',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
