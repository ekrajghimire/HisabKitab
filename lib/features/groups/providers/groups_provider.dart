import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/group_model.dart';

class GroupsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<GroupModel> _groups = [];
  String? _errorMessage;
  bool _isLoading = false;

  List<GroupModel> get groups => _groups;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> fetchUserGroups(String userId) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Query for groups where user is a member
      final querySnapshot =
          await _firestore
              .collection(AppConstants.groupsCollection)
              .where('memberIds', arrayContains: userId)
              .get();

      _groups =
          querySnapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data()..['id'] = doc.id))
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to fetch groups: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<GroupModel?> createGroup({
    required String name,
    String? description,
    required String creatorId,
    List<String>? additionalMemberIds,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final now = DateTime.now();
      final groupId = const Uuid().v4();

      // Initialize member list with creator
      final memberIds = <String>[creatorId];

      // Add additional members if provided
      if (additionalMemberIds != null && additionalMemberIds.isNotEmpty) {
        memberIds.addAll(additionalMemberIds);
      }

      final newGroup = GroupModel(
        id: groupId,
        name: name,
        description: description,
        creatorId: creatorId,
        memberIds: memberIds,
        imageUrl: null,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .set(newGroup.toMap());

      // Update user documents to include this group
      for (final memberId in memberIds) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(memberId)
            .update({
              'groupIds': FieldValue.arrayUnion([groupId]),
            });
      }

      _groups.add(newGroup);
      _isLoading = false;
      notifyListeners();

      return newGroup;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to create group: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateGroup(GroupModel updatedGroup) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updateData = {
        'name': updatedGroup.name,
        'description': updatedGroup.description,
        'imageUrl': updatedGroup.imageUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(updatedGroup.id)
          .update(updateData);

      final index = _groups.indexWhere((g) => g.id == updatedGroup.id);
      if (index != -1) {
        _groups[index] = updatedGroup;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update group: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Get group to access member IDs
      final groupDoc =
          await _firestore
              .collection(AppConstants.groupsCollection)
              .doc(groupId)
              .get();

      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final List<dynamic> memberIds = groupData['memberIds'];

        // Remove groupId from all member documents
        for (final memberId in memberIds) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(memberId.toString())
              .update({
                'groupIds': FieldValue.arrayRemove([groupId]),
              });
        }
      }

      // Delete the group document
      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .delete();

      _groups.removeWhere((g) => g.id == groupId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete group: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMember(String groupId, String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update({
            'memberIds': FieldValue.arrayUnion([userId]),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Update user's groupIds
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
            'groupIds': FieldValue.arrayUnion([groupId]),
          });

      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        final updatedMemberIds = List<String>.from(_groups[index].memberIds)
          ..add(userId);
        _groups[index] = _groups[index].copyWith(memberIds: updatedMemberIds);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to add member: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String groupId, String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update({
            'memberIds': FieldValue.arrayRemove([userId]),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Update user's groupIds
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
            'groupIds': FieldValue.arrayRemove([groupId]),
          });

      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        final updatedMemberIds = List<String>.from(_groups[index].memberIds)
          ..remove(userId);
        _groups[index] = _groups[index].copyWith(memberIds: updatedMemberIds);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to remove member: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
