import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trips_provider.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Add controllers for participant fields
  final List<TextEditingController> _participantControllers = [
    TextEditingController(),
  ];

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCurrency = '₹';

  // Date fields for trip
  final DateTime _startDate = DateTime.now();
  final DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // Supported currencies
  final List<String> _currencies = ['₹', '\$', '€', '£', '¥'];

  // Current step in the creation process
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var controller in _participantControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addParticipant() {
    setState(() {
      _participantControllers.add(TextEditingController());
    });
  }

  void _removeParticipant(int index) {
    if (_participantControllers.length > 1) {
      setState(() {
        _participantControllers[index].dispose();
        _participantControllers.removeAt(index);
      });
    }
  }

  Future<void> _createTrip() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);

      if (authProvider.user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to be logged in to create a trip';
        });
        return;
      }

      try {
        // Generate a unique ID for the trip's group
        final groupId =
            'group_${DateTime.now().millisecondsSinceEpoch}_${authProvider.user!.uid.substring(0, 5)}';

        // Use user ID for the current user
        final currentUserId = authProvider.user!.uid;
        List<String> members = [currentUserId]; // Start with creator's user ID
        for (var i = 1; i < _participantControllers.length; i++) {
          if (_participantControllers[i].text.isNotEmpty) {
            members.add(_participantControllers[i].text.trim());
          }
        }

        // Create trip directly in local storage
        final trip = await tripsProvider.createTrip(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          groupId: groupId,
          createdBy: authProvider.user!.uid,
          startDate: _startDate,
          endDate: _endDate,
          currency: _selectedCurrency,
          members: members,
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (trip != null) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip "${trip.name}" created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Allow the snackbar to be visible briefly before navigating
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop(trip);
            }
          });
        } else {
          setState(() {
            _errorMessage =
                tripsProvider.errorMessage ?? 'Failed to create trip';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error creating trip: ${e.toString()}';
        });
        print('Error creating trip: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create New Trip'),
        backgroundColor: Colors.black,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() {
              _currentStep += 1;
            });
          } else {
            _createTrip();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              _currentStep < 2 ? 'Continue' : 'Create Trip',
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text(
              'Trip Details',
              style: TextStyle(color: Colors.white),
            ),
            content: _buildTripDetailsForm(),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text(
              'Select Currency',
              style: TextStyle(color: Colors.white),
            ),
            content: _buildCurrencySelectionForm(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text(
              'Add Participants',
              style: TextStyle(color: Colors.white),
            ),
            content: _buildParticipantsForm(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trip Name
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Trip Name',
              hintText: 'Where are you going?',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: const Icon(Icons.place, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a trip name';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Trip Description
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Add some details about your trip',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: const Icon(Icons.description, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            maxLines: 3,
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelectionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Currency selection
        Text(
          'Select a currency for your trip',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              _currencies.map((currency) {
                final isSelected = currency == _selectedCurrency;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = currency;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          isSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                    ),
                    child: Text(
                      currency,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildParticipantsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add trip participants',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _participantControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _participantControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText:
                            index == 0
                                ? 'Your name (automatically included)'
                                : 'Participant ${index + 1}',
                        hintText: 'Enter name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        enabled: index > 0, // First participant is current user
                      ),
                    ),
                  ),
                  if (index > 0)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeParticipant(index),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _addParticipant,
          icon: const Icon(Icons.add, color: Colors.blue),
          label: const Text(
            'Add Another Participant',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}
