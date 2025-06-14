import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/group_model.dart';
import '../../../core/services/mongo_db_service.dart';

class GroupsProvider with ChangeNotifier {
  final MongoDBService _mongoDb = MongoDBService.instance;

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

      // Query for groups where user is a member from MongoDB
      final groupMaps = await _mongoDb.getGroupsForUser(userId);
      _groups = groupMaps.map((map) => GroupModel.fromMap(map)).toList();

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
    String? iconName,
    required String currency,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final now = DateTime.now();
      final groupId = const Uuid().v4();

      final memberIds = [creatorId];
      if (additionalMemberIds != null) {
        memberIds.addAll(additionalMemberIds);
      }

      final group = GroupModel(
        id: groupId,
        name: name,
        description: description ?? '',
        creatorId: creatorId,
        memberIds: memberIds,
        iconName: iconName ?? 'beach_access',
        currency: currency,
        createdAt: now,
        updatedAt: now,
      );

      // Save to MongoDB
      await _mongoDb.saveGroup(group.toMap()..['id'] = groupId);

      // Update local state
      _groups.add(group);

      _isLoading = false;
      notifyListeners();

      return group;
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
        ...updatedGroup.toMap(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _mongoDb.saveGroup(updateData);

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

      // Delete the group document from MongoDB
      await _mongoDb.deleteGroup(groupId);

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

      await _mongoDb.addGroupMember(groupId, userId);

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

      await _mongoDb.removeGroupMember(groupId, userId);

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
