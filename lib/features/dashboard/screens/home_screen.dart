import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/group_model.dart';
import '../../../models/trip_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/screens/group_details_screen.dart';
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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);

    if (authProvider.user != null) {
      // Load user's groups
      await groupsProvider.fetchUserGroups(authProvider.user!.uid);

      // Load user's trips
      await tripsProvider.fetchUserTrips(authProvider.user!.uid);
    }
  }

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                      // Refresh the trips list
                      _loadUserData();

                      // Navigate to the trip details screen
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
                backgroundColor: const Color(
                  0xFF003366,
                ), // Dark blue background
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.blue,
                    width: 2.0,
                  ), // Light blue border
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.blue, // Light blue plus icon
                  size: 36,
                ),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
        backgroundColor: const Color(
          0xFF121212,
        ), // Slightly lighter than pure black
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white.withOpacity(0.5),
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripsProvider>(
      builder: (context, tripsProvider, child) {
        final trips = tripsProvider.trips;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HisabKitab',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                if (trips.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        SizedBox(height: 40),
                        Icon(
                          Icons.card_travel,
                          size: 64,
                          color: Colors.blue.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No trips yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first trip using the + button',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
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
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade900,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_travel,
                  color: Colors.amber,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (trip.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          trip.description,
                          style: TextStyle(color: Colors.grey.shade400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${trip.members.length}',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.person, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
