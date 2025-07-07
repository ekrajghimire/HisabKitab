import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/screens/my_trips_screen.dart';
import '../../groups/screens/create_trip_screen.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/providers/trips_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../trips/screens/trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const MyTripsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      // Load groups
      final groupsProvider = Provider.of<GroupsProvider>(
        context,
        listen: false,
      );
      await groupsProvider.fetchUserGroups(user.uid);

      // Load trips
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      await tripsProvider.fetchUserTrips(user.uid);
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Refresh data when returning to home tab (index 0)
    if (index == 0) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _screens[_currentIndex],
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  ).then((result) {
                    if (result != null) {
                      _loadUserData();
                      if (result is TripModel) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => TripDetailScreen(trip: result),
                          ),
                        );
                      }
                    }
                  });
                },
                backgroundColor: const Color(0xFF003366),
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.blue, width: 2.0),
                ),
                child: const Icon(Icons.add, color: Colors.blue, size: 36),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            isDarkMode
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Text(
              'HK',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.luggage), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();
    // Ensure data is loaded when this widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);

    if (authProvider.user != null) {
      await tripsProvider.fetchUserTrips(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripsProvider>(
      builder: (context, tripsProvider, child) {
        final trips = tripsProvider.trips;

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HisabKitab',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (trips.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_travel,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No trips yet',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first trip using the + button',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return TripCard(
                            trip: trip,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => TripDetailScreen(trip: trip),
                                ),
                              ).then((_) {
                                // Refresh data when returning from trip detail
                                _refreshData();
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;

  const TripCard({required this.trip, required this.onTap, super.key});

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color:
          isDarkMode
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTripIcon(trip.icon),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(trip.createdAt),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
              if (trip.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  trip.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTripIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'beach':
        return Icons.beach_access;
      case 'mountain':
        return Icons.landscape;
      case 'city':
        return Icons.location_city;
      case 'food':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'business':
        return Icons.business;
      case 'family':
        return Icons.family_restroom;
      case 'friends':
        return Icons.group;
      case 'camping':
        return Icons.forest;
      case 'hiking':
        return Icons.hiking;
      case 'sports':
        return Icons.sports;
      case 'music':
        return Icons.music_note;
      case 'art':
        return Icons.palette;
      case 'education':
        return Icons.school;
      case 'health':
        return Icons.health_and_safety;
      case 'wedding':
        return Icons.favorite;
      case 'birthday':
        return Icons.cake;
      case 'concert':
        return Icons.theater_comedy;
      case 'movie':
        return Icons.movie;
      case 'gaming':
        return Icons.sports_esports;
      default:
        return Icons.luggage;
    }
  }
}
