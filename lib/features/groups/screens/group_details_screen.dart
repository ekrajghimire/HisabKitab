import 'package:flutter/material.dart';
import '../../../models/group_model.dart';
import '../../../models/trip_model.dart';
import '../../trips/screens/trip_detail_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final GroupModel group;
  final bool fromCreation;

  const GroupDetailsScreen({
    required this.group,
    this.fromCreation = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Create a trip model from the group data
    final trip = TripModel(
      id: group.id,
      name: group.name,
      description: group.description ?? '',
      groupId: group.id,
      createdBy: group.creatorId,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      currency: group.currency ?? 'INR',
      members: group.memberIds,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      icon: group.iconName ?? 'group',
    );

    // Navigate to TripDetailScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
      );
    });

    // Show loading screen while navigation is pending
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.blue)),
    );
  }
}
