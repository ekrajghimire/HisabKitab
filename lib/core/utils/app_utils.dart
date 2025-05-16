import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

class AppUtils {
  // Generate unique ID
  static String generateUid() {
    const uuid = Uuid();
    return uuid.v4();
  }

  // Format currency
  static String formatCurrency(double amount, String currencyCode) {
    final symbol = AppConstants.currencySymbols[currencyCode] ?? currencyCode;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  // Format date
  static String formatDate(DateTime date, {bool showYear = true}) {
    if (showYear) {
      return DateFormat.yMMMd().format(date);
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  // Format time
  static String formatTime(DateTime time) {
    return DateFormat.jm().format(time);
  }

  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  // Calculate time ago
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }

  // Calculate balances between group members
  static Map<String, Map<String, double>> calculateBalances(
    List<Map<String, dynamic>> expenses,
  ) {
    // Map of userId -> (Map of otherUserId -> amount)
    final Map<String, Map<String, double>> balances = {};

    for (var expense in expenses) {
      final String paidById = expense['paidById'];
      final List<dynamic> splits = expense['splits'];

      for (var split in splits) {
        final String userId = split['userId'];
        final double amount = split['amount'];

        if (userId != paidById) {
          // User owes the payer
          balances[userId] = balances[userId] ?? {};
          balances[userId]![paidById] =
              (balances[userId]![paidById] ?? 0) + amount;

          // Payer is owed by the user
          balances[paidById] = balances[paidById] ?? {};
          balances[paidById]![userId] =
              (balances[paidById]![userId] ?? 0) - amount;
        }
      }
    }

    // Simplify balances (remove zero or very small amounts due to floating point precision)
    for (var userId in balances.keys) {
      balances[userId]!.removeWhere((otherId, amount) => amount.abs() < 0.01);
    }

    return balances;
  }

  // Show a snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Validate email
  static bool isValidEmail(String email) {
    final regex = RegExp(AppConstants.emailRegex);
    return regex.hasMatch(email);
  }

  // Validate password
  static bool isValidPassword(String password) {
    final regex = RegExp(AppConstants.passwordRegex);
    return regex.hasMatch(password);
  }

  // Check internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // This would normally use connectivity_plus package
      // For now, return true as a placeholder
      return true;
    } catch (e) {
      return false;
    }
  }

  // Distribute amount evenly among members
  static List<Map<String, dynamic>> splitEqually(
    double totalAmount,
    List<Map<String, String>> members,
  ) {
    final perPersonAmount = totalAmount / members.length;
    return members
        .map(
          (member) => {
            'userId': member['userId'],
            'name': member['name'],
            'amount': perPersonAmount,
          },
        )
        .toList();
  }
}
