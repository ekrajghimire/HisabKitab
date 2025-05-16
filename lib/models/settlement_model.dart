import 'dart:convert';

class SettlementModel {
  final String id;
  final String groupId;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;
  final String currency;
  final DateTime date;
  final String? notes;
  final String? imageUrl;
  final String status; // 'pending', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  SettlementModel copyWith({
    String? id,
    String? groupId,
    String? fromUserId,
    String? fromUserName,
    String? toUserId,
    String? toUserName,
    double? amount,
    String? currency,
    DateTime? date,
    String? notes,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'amount': amount,
      'currency': currency,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    return SettlementModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? '',
      toUserId: map['toUserId'] ?? '',
      toUserName: map['toUserName'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      notes: map['notes'],
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory SettlementModel.fromJson(String source) =>
      SettlementModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'SettlementModel(id: $id, groupId: $groupId, fromUserId: $fromUserId, fromUserName: $fromUserName, toUserId: $toUserId, toUserName: $toUserName, amount: $amount, currency: $currency, date: $date, notes: $notes, imageUrl: $imageUrl, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SettlementModel &&
        other.id == id &&
        other.groupId == groupId &&
        other.fromUserId == fromUserId &&
        other.toUserId == toUserId &&
        other.amount == amount &&
        other.currency == currency &&
        other.date == date &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        fromUserId.hashCode ^
        toUserId.hashCode ^
        amount.hashCode ^
        currency.hashCode ^
        date.hashCode ^
        status.hashCode;
  }
}
