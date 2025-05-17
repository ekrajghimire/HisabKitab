import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/theme_provider.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'Guest User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Appearance Settings
          _buildSectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode, color: Colors.blue),
            title: const Text(
              'Dark Mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Apply dark theme to the app',
              style: TextStyle(color: Colors.grey),
            ),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: Colors.blue,
            ),
          ),

          const SizedBox(height: 16),

          // Account Settings
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update your personal information',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // Edit profile to be implemented
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.blue),
            title: const Text(
              'Change Password',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update your account password',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // Change password to be implemented
            },
          ),

          const SizedBox(height: 16),

          // Support Section
          _buildSectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help, color: Colors.blue),
            title: const Text(
              'Help & Support',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Get assistance with the app',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // Help & support to be implemented
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.blue),
            title: const Text('About', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'App version and information',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // About to be implemented
            },
          ),

          const SizedBox(height: 24),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () async {
                final confirmed = await _showLogoutConfirmation(context);
                if (confirmed && context.mounted) {
                  final result = await authProvider.signOut();
                  if (result && context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Logout', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
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
