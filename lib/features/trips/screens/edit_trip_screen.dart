import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../models/trip_model.dart';
import '../providers/trips_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';

class EditTripScreen extends StatefulWidget {
  final TripModel trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _currency;
  bool _isLoading = false;
  List<UserModel> _participants = [];
  List<String> _selectedParticipantIds = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trip.name);
    _descriptionController = TextEditingController(
      text: widget.trip.description,
    );
    _startDate = widget.trip.startDate;
    _endDate = widget.trip.endDate;
    _currency = widget.trip.currency;
    _selectedParticipantIds = List.from(widget.trip.members);
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      // Load all users that are part of the trip
      final users = await authProvider.getUsersByIds(widget.trip.members);
      setState(() {
        _participants = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading participants: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _addParticipant() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await showDialog<UserModel>(
      context: context,
      builder:
          (context) => AddParticipantDialog(
            currentParticipantIds: _selectedParticipantIds,
          ),
    );

    if (result != null && mounted) {
      setState(() {
        if (!_selectedParticipantIds.contains(result.uid)) {
          _selectedParticipantIds.add(result.uid);
          _participants.add(result);
        }
      });
    }
  }

  void _removeParticipant(String userId) {
    setState(() {
      _selectedParticipantIds.remove(userId);
      _participants.removeWhere((user) => user.uid == userId);
    });
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one participant')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedTrip = widget.trip.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        currency: _currency,
        members: _selectedParticipantIds,
        updatedAt: DateTime.now(),
      );

      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      await tripsProvider.updateTrip(updatedTrip);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating trip: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Trip'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveTrip,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a trip name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                    ),
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      '${_endDate.year}-${_endDate.month}-${_endDate.day}',
                    ),
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                DropdownMenuItem(value: '£', child: Text('GBP (£)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: _addParticipant,
                  tooltip: 'Add Participant',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_participants.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No participants added yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final participant = _participants[index];
                  final isCurrentUser =
                      participant.uid ==
                      Provider.of<AuthProvider>(context).user?.uid;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            participant.photoUrl != null
                                ? NetworkImage(participant.photoUrl!)
                                : null,
                        child:
                            participant.photoUrl == null
                                ? Text(participant.name[0].toUpperCase())
                                : null,
                      ),
                      title: Text(
                        isCurrentUser
                            ? '${participant.name} (You)'
                            : participant.name,
                      ),
                      subtitle: Text(participant.email),
                      trailing:
                          isCurrentUser
                              ? const Icon(Icons.star, color: Colors.amber)
                              : IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                onPressed:
                                    () => _removeParticipant(participant.uid),
                                tooltip: 'Remove Participant',
                              ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class AddParticipantDialog extends StatefulWidget {
  final List<String> currentParticipantIds;

  const AddParticipantDialog({super.key, required this.currentParticipantIds});

  @override
  State<AddParticipantDialog> createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends State<AddParticipantDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final results = await authProvider.searchUsers(query);

      // Filter out users that are already participants
      final filteredResults =
          results
              .where((user) => !widget.currentParticipantIds.contains(user.uid))
              .toList();

      if (mounted) {
        setState(() {
          _searchResults = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching users: $e')));
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Participant',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_searchResults.isEmpty &&
                _searchController.text.isNotEmpty)
              const Text('No users found')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            user.photoUrl != null
                                ? NetworkImage(user.photoUrl!)
                                : null,
                        child:
                            user.photoUrl == null
                                ? Text(user.name[0].toUpperCase())
                                : null,
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onTap: () => Navigator.of(context).pop(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
