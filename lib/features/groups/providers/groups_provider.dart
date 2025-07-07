import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/group_model.dart';
import '../../../core/services/mongo_db_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GroupsProvider with ChangeNotifier {
  final MongoDBService _mongoDb = MongoDBService.instance;

  List<GroupModel> _groups = [];
  String? _errorMessage;
  bool _isLoading = false;
  bool _isOnline = true;

  List<GroupModel> get groups => _groups;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;

  GroupsProvider() {
    // Initialize connectivity listener
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      // If we just came back online, trigger a sync
      if (!wasOnline && _isOnline) {
        _syncGroups();
      }
      notifyListeners();
    });
  }

  Future<void> fetchUserGroups(String userId) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      List<GroupModel> fetchedGroups = [];

      // Try to fetch from MongoDB if online
      if (_isOnline) {
        try {
          final groupMaps = await _mongoDb.getGroupsForUser(userId);
          fetchedGroups =
              groupMaps.map((map) => GroupModel.fromMap(map)).toList();

          // Save fetched groups to local storage
          for (final group in fetchedGroups) {
            await LocalStorageService.saveGroup(group);
          }
        } catch (e) {
          debugPrint('Failed to fetch from MongoDB: $e');
          // If MongoDB fails, fall back to local storage
          fetchedGroups = await LocalStorageService.getGroupsForUser(userId);
        }
      } else {
        // Offline mode - get from local storage
        fetchedGroups = await LocalStorageService.getGroupsForUser(userId);
      }

      _groups = fetchedGroups;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to fetch groups: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _syncGroups() async {
    if (!_isOnline) return;

    try {
      // Get local groups
      final localGroups = await LocalStorageService.getAllGroups();

      // Get MongoDB groups
      final mongoGroups =
          (await _mongoDb.getGroupsForUser(
            _groups.first.creatorId,
          )).map((data) => GroupModel.fromMap(data)).toList();

      // Compare and sync
      for (final localGroup in localGroups) {
        final mongoGroup = mongoGroups.firstWhere(
          (g) => g.id == localGroup.id,
          orElse: () => localGroup,
        );

        // If local group is newer or MongoDB doesn't have it
        if (localGroup.updatedAt.isAfter(mongoGroup.updatedAt)) {
          await _mongoDb.saveGroup(localGroup.toMap());
        }
      }

      // Update local storage with any new groups from MongoDB
      for (final mongoGroup in mongoGroups) {
        final localGroup = localGroups.firstWhere(
          (g) => g.id == mongoGroup.id,
          orElse: () => mongoGroup,
        );

        // If MongoDB group is newer or local doesn't have it
        if (mongoGroup.updatedAt.isAfter(localGroup.updatedAt)) {
          await LocalStorageService.saveGroup(mongoGroup);
        }
      }

      // Update last sync timestamp
      await LocalStorageService.updateLastSyncTimestamp();
    } catch (e) {
      debugPrint('Error during group sync: $e');
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

      // Save to local storage first
      await LocalStorageService.saveGroup(group);

      // Try to save to MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.saveGroup(group.toMap()..['id'] = groupId);
        } catch (e) {
          debugPrint('Failed to save to MongoDB: $e');
          // Continue since we have local copy
        }
      }

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

      // Save to local storage first
      await LocalStorageService.saveGroup(updatedGroup);

      // Try to save to MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.saveGroup(updateData);
        } catch (e) {
          debugPrint('Failed to save to MongoDB: $e');
          // Continue since we have local copy
        }
      }

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

      // Delete from local storage first
      await LocalStorageService.deleteGroup(groupId);

      // Try to delete from MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.deleteGroup(groupId);
        } catch (e) {
          debugPrint('Failed to delete from MongoDB: $e');
          // Continue since we deleted local copy
        }
      }

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

      // Update local storage first
      final group = _groups.firstWhere((g) => g.id == groupId);
      final updatedGroup = group.copyWith(
        memberIds: [...group.memberIds, userId],
        updatedAt: DateTime.now(),
      );
      await LocalStorageService.saveGroup(updatedGroup);

      // Try to update MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.addGroupMember(groupId, userId);
        } catch (e) {
          debugPrint('Failed to add member in MongoDB: $e');
          // Continue since we updated local copy
        }
      }

      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
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

      // Update local storage first
      final group = _groups.firstWhere((g) => g.id == groupId);
      final updatedGroup = group.copyWith(
        memberIds: [...group.memberIds]..remove(userId),
        updatedAt: DateTime.now(),
      );
      await LocalStorageService.saveGroup(updatedGroup);

      // Try to update MongoDB if online
      if (_isOnline) {
        try {
          await _mongoDb.removeGroupMember(groupId, userId);
        } catch (e) {
          debugPrint('Failed to remove member in MongoDB: $e');
          // Continue since we updated local copy
        }
      }

      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
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
