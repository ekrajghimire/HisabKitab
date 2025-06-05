import 'dart:convert';
import 'package:fixnum/fixnum.dart';

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
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidById': paidById,
      'splitAmounts': splitAmounts,
      'description': description,
      'category': category,
      'receiptUrl': receiptUrl,
      'date': date.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final date =
        map['date'] is Int64
            ? DateTime.fromMillisecondsSinceEpoch(map['date'].toInt())
            : DateTime.fromMillisecondsSinceEpoch(map['date'] as int);

    final createdAt =
        map['createdAt'] is Int64
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'].toInt())
            : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int);

    final updatedAt =
        map['updatedAt'] is Int64
            ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'].toInt())
            : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int);

    // Convert split amounts to Map<String, double>
    final splitAmountsRaw = map['splitAmounts'] as Map<String, dynamic>;
    final splitAmounts = splitAmountsRaw.map((key, value) {
      if (value is int) {
        return MapEntry(key, value.toDouble());
      }
      return MapEntry(key, value as double);
    });

    return ExpenseModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidById: map['paidById'] as String,
      splitAmounts: splitAmounts,
      description: map['description'] as String?,
      category: map['category'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
