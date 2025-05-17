import 'package:flutter/material.dart';
import '../../../models/group_model.dart';
import 'trip_details_screen.dart';

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
    // Instead of showing own UI, navigate to TripDetailsScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => TripDetailsScreen(
                group: group,
                autoShowExpenses: fromCreation,
              ),
        ),
      );
    });

    // Show loading screen while navigation is pending
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.blue)),
    );
  }
}
