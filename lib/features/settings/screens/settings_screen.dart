import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'db_setup_screen.dart';
import 'mongodb_config_screen.dart';
import 'sync_screen.dart';
import '../../../core/widgets/mongodb_status_indicator.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings
          _buildSectionHeader(context, 'Appearance'),
          _buildSettingTile(
            context,
            'Dark Mode',
            'Apply dark theme to the app',
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.setDarkMode(value),
              activeColor: Colors.blue,
            ),
          ),

          const Divider(color: Colors.grey),

          // Developer Settings
          _buildSectionHeader(context, 'Cloud Sync'),
          _buildSettingTile(
            context,
            'MongoDB Configuration',
            'Set up cloud synchronization',
            trailing: const MongoDBStatusIndicator(showLabel: false),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MongoDBConfigScreen()),
              );
            },
          ),
          _buildSettingTile(
            context,
            'Sync Data',
            'Manually sync data with MongoDB',
            trailing: const Icon(Icons.sync, size: 20, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),

          const Divider(color: Colors.grey),

          // Developer Section
          _buildSectionHeader(context, 'Developer'),
          _buildSettingTile(
            context,
            'Database Setup',
            'Configure Firestore collections',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DbSetupScreen()),
              );
            },
          ),

          const Divider(color: Colors.grey),

          // Account Settings
          _buildSectionHeader(context, 'Account'),
          _buildSettingTile(
            context,
            'Logout',
            'Sign out from your account',
            onTap: () async {
              final confirmed = await _showLogoutConfirmation(context);
              if (confirmed && context.mounted) {
                await authProvider.signOut();
                // Navigator should be handled by auth state changes
              }
            },
            textColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      ),
      trailing:
          trailing ??
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return result ?? false;
  }
}
