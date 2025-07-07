import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/groups/providers/groups_provider.dart';
import '../../../models/group_model.dart';
import '../../../core/utils/app_utils.dart';
import 'create_trip_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    if (authProvider.user != null) {
      await groupsProvider.fetchUserGroups(authProvider.user!.uid);
    }
  }

  Future<void> _refreshGroups() async {
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    // The actual content of this screen is not displayed
    // since it's replaced by the HomeContent class in home_screen.dart
    return Container();
  }
}
