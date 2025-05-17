import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../../trips/screens/trip_detail_screen.dart';

class AddTripScreen extends StatefulWidget {
  final String groupId;

  const AddTripScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  _AddTripScreenState createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String _currency = 'USD';
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTrip() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final tripsProvider = Provider.of<TripsProvider>(
          context,
          listen: false,
        );

        // Debug output
        print('Creating trip with data:');
        print('Name: ${_nameController.text}');
        print('Description: ${_descriptionController.text}');
        print('Group ID: ${widget.groupId}');
        print('User ID: ${authProvider.user?.uid}');

        if (authProvider.user == null) {
          throw Exception('User not logged in');
        }

        final result = await tripsProvider.createTrip(
          name: _nameController.text,
          description: _descriptionController.text,
          groupId: widget.groupId,
          createdBy: authProvider.user!.uid,
          startDate: _startDate,
          endDate: _endDate,
          currency: _currency,
          members: [authProvider.user!.uid],
        );

        if (result != null) {
          print('Trip created successfully: ${result.id}');

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip created successfully!')),
          );

          // Navigate to trip detail screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => TripDetailScreen(trip: result),
              ),
            );
          }
        } else {
          throw Exception(
            'Failed to create trip: ${tripsProvider.errorMessage}',
          );
        }
      } catch (e) {
        print('Error creating trip: $e');
        setState(() {
          _error = e.toString();
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_error}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Trip')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Trip Name'),
              validator:
                  (value) =>
                      (value?.isEmpty ?? true)
                          ? 'Please enter trip name'
                          : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(DateFormat('MMM d, yyyy').format(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: _startDate.add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items:
                  ['USD', 'EUR', 'INR', 'GBP']
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveTrip,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                      : const Text('Create Trip'),
            ),
          ],
        ),
      ),
    );
  }
}
