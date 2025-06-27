import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../../../core/constants/currency_constants.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Add controllers for participant fields
  final List<TextEditingController> _participantControllers = [
    TextEditingController(),
  ];

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCurrency = 'INR'; // Default to INR

  // Date fields for trip
  final DateTime _startDate = DateTime.now();
  final DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // Current step in the creation process
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
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
          groupId: groupId,
          createdBy: authProvider.user!.uid,
          startDate: _startDate,
          endDate: _endDate,
          currency: _selectedCurrency,
          members: members,
          description: '',
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
        Text(
          'Select a currency for your trip',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              isExpanded: true,
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              items:
                  CurrencyConstants.currencies.keys.map((String code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Row(
                        children: [
                          Text(
                            CurrencyConstants.getSymbol(code),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(code),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCurrency = newValue;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Preview of selected currency
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Selected: ${CurrencyConstants.getFormattedCurrency(_selectedCurrency)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
