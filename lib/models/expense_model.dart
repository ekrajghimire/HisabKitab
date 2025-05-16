import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSplit {
  final String userId;
  final String name;
  final double amount;
  final int? shares;
  final double? percentage;

  ExpenseSplit({
    required this.userId,
    required this.name,
    required this.amount,
    this.shares,
    this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'shares': shares,
      'percentage': percentage,
    };
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      shares: map['shares'],
      percentage: map['percentage']?.toDouble(),
    );
  }
}

class ExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidById;
  final Map<String, double> splitAmounts; // userId: amount
  final String? description;
  final String? category;
  final String? receiptUrl;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidById,
    required this.splitAmounts,
    this.description,
    this.category,
    this.receiptUrl,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  ExpenseModel copyWith({
    String? id,
    String? groupId,
    String? title,
    double? amount,
    String? paidById,
    Map<String, double>? splitAmounts,
    String? description,
    String? category,
    String? receiptUrl,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidById: paidById ?? this.paidById,
      splitAmounts: splitAmounts ?? this.splitAmounts,
      description: description ?? this.description,
      category: category ?? this.category,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidById': paidById,
      'splitAmounts': splitAmounts,
      'description': description,
      'category': category,
      'receiptUrl': receiptUrl,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    // Convert Firestore Timestamp to DateTime
    final dateTimestamp = map['date'] as Timestamp;
    final createdAtTimestamp = map['createdAt'] as Timestamp;
    final updatedAtTimestamp = map['updatedAt'] as Timestamp;

    // Convert the splitAmounts from Firestore
    final splitAmountsMap = map['splitAmounts'] as Map<String, dynamic>;
    final splitAmounts = <String, double>{};

    splitAmountsMap.forEach((key, value) {
      splitAmounts[key] = (value is int) ? value.toDouble() : value;
    });

    return ExpenseModel(
      id: map['id'],
      groupId: map['groupId'],
      title: map['title'],
      amount:
          (map['amount'] is int)
              ? (map['amount'] as int).toDouble()
              : map['amount'],
      paidById: map['paidById'],
      splitAmounts: splitAmounts,
      description: map['description'],
      category: map['category'],
      receiptUrl: map['receiptUrl'],
      date: dateTimestamp.toDate(),
      createdAt: createdAtTimestamp.toDate(),
      updatedAt: updatedAtTimestamp.toDate(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ExpenseModel.fromJson(String source) =>
      ExpenseModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ExpenseModel(id: $id, groupId: $groupId, title: $title, amount: $amount, paidById: $paidById, splitAmounts: $splitAmounts, description: $description, category: $category, receiptUrl: $receiptUrl, date: $date, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ExpenseModel &&
        other.id == id &&
        other.groupId == groupId &&
        other.title == title &&
        other.amount == amount &&
        other.paidById == paidById &&
        other.splitAmounts == splitAmounts &&
        other.description == description &&
        other.category == category &&
        other.receiptUrl == receiptUrl &&
        other.date == date &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        title.hashCode ^
        amount.hashCode ^
        paidById.hashCode ^
        splitAmounts.hashCode ^
        description.hashCode ^
        category.hashCode ^
        receiptUrl.hashCode ^
        date.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
