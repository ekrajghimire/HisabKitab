import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class TripModel {
  final String id;
  final String name;
  final String description;
  final String groupId;
  final String createdBy;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final List<String> members;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String icon;

  TripModel({
    required this.id,
    required this.name,
    required this.description,
    required this.groupId,
    required this.createdBy,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.icon = 'luggage',
  });

  // Convert to Map for Firestore or local storage
  Map<String, dynamic> toMap() {
    return {
      // id is stored as document id in Firestore, but we include it for local storage
      'id': id,
      'name': name,
      'description': description,
      'groupId': groupId,
      'createdBy': createdBy,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'currency': currency,
      'members': members,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'icon': icon,
    };
  }

  // Convenience method to convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create from Map from Firestore or local storage
  factory TripModel.fromMap(Map<String, dynamic> map) {
    try {
      print('Creating TripModel from map: $map');

      // Handle both Timestamp and milliseconds formats for dates
      DateTime parseDate(dynamic value) {
        if (value is Timestamp) {
          return value.toDate();
        } else if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else if (value is DateTime) {
          return value;
        }
        throw Exception('Invalid date format: $value (${value.runtimeType})');
      }

      final String id = map['id'] ?? '';
      final String name = map['name'] ?? '';
      final String description = map['description'] ?? '';
      final String groupId = map['groupId'] ?? '';
      final String createdBy = map['createdBy'] ?? '';
      final String currency = map['currency'] ?? 'USD';
      final String icon = map['icon'] ?? 'luggage';

      // Parse dates
      DateTime startDate;
      DateTime endDate;
      DateTime createdAt;
      DateTime updatedAt;

      try {
        startDate = parseDate(map['startDate']);
        endDate = parseDate(map['endDate']);
        createdAt = parseDate(map['createdAt']);
        updatedAt = parseDate(map['updatedAt']);
      } catch (e) {
        print('Error parsing dates: $e');
        // Fallback to current time if date parsing fails
        final now = DateTime.now();
        startDate = now;
        endDate = now.add(const Duration(days: 7));
        createdAt = now;
        updatedAt = now;
      }

      // Parse members
      List<String> members;
      try {
        members = List<String>.from(map['members'] ?? []);
      } catch (e) {
        print('Error parsing members: $e');
        members = [];
      }

      return TripModel(
        id: id,
        name: name,
        description: description,
        groupId: groupId,
        createdBy: createdBy,
        startDate: startDate,
        endDate: endDate,
        currency: currency,
        members: members,
        createdAt: createdAt,
        updatedAt: updatedAt,
        icon: icon,
      );
    } catch (e) {
      print('Error creating TripModel: $e');
      rethrow;
    }
  }

  // Create from JSON string
  factory TripModel.fromJson(String json) =>
      TripModel.fromMap(jsonDecode(json));

  // Helper for debugging
  @override
  String toString() {
    return 'TripModel(id: $id, name: $name, groupId: $groupId)';
  }
}
