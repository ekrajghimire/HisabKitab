import 'package:flutter/material.dart';
import '../../../core/services/mongo_db_service.dart';

class MongoDBConfigScreen extends StatefulWidget {
  const MongoDBConfigScreen({Key? key}) : super(key: key);

  @override
  _MongoDBConfigScreenState createState() => _MongoDBConfigScreenState();
}

class _MongoDBConfigScreenState extends State<MongoDBConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _connectionStringController;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  bool _connectionSuccess = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _connectionStringController = TextEditingController();
    _loadCurrentConnectionString();
  }

  Future<void> _loadCurrentConnectionString() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connString = await MongoDBService.instance.getConnectionString();
      _connectionStringController.text = connString;

      // Check if connection is valid
      final isValid = await MongoDBService.instance.hasValidConnectionString();
      if (isValid) {
        setState(() {
          _connectionStatus = 'Connection string is configured';
          _connectionSuccess = true;
        });
      } else {
        setState(() {
          _connectionStatus = 'Connection string needs configuration';
          _connectionSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error loading connection string: ${e.toString()}';
        _connectionSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isTestingConnection = true;
        _connectionStatus = 'Testing connection...';
        _connectionSuccess = false;
      });

      try {
        final success = await MongoDBService.instance.testConnection(
          _connectionStringController.text.trim(),
        );

        if (success) {
          setState(() {
            _connectionStatus = 'Connection successful!';
            _connectionSuccess = true;
          });
        } else {
          setState(() {
            _connectionStatus =
                'Connection failed. Please check your connection string.';
            _connectionSuccess = false;
          });
        }
      } catch (e) {
        setState(() {
          _connectionStatus = 'Error testing connection: ${e.toString()}';
          _connectionSuccess = false;
        });
      } finally {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _saveConnectionString() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _connectionStatus = 'Saving connection string...';
      });

      try {
        await MongoDBService.instance.setConnectionString(
          _connectionStringController.text.trim(),
        );

        setState(() {
          _connectionStatus = 'Connection string saved successfully!';
          _connectionSuccess = true;
        });

        // Show success dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('MongoDB configuration saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _connectionStatus = 'Error saving connection string: ${e.toString()}';
          _connectionSuccess = false;
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MongoDB Configuration'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MongoDB Connection',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Configure your MongoDB connection string to enable cloud sync. For MongoDB Atlas, use the format:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'mongodb+srv://username:password@cluster.example.mongodb.net/hisabkitab',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Note: You can find this connection string in your MongoDB Atlas dashboard under "Connect" > "Connect your application".',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),

                      TextFormField(
                        controller: _connectionStringController,
                        decoration: InputDecoration(
                          labelText: 'MongoDB Connection String',
                          hintText: 'mongodb+srv://...',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a connection string';
                          }
                          if (value.contains('<username>') ||
                              value.contains('<password>') ||
                              value.contains('<cluster>')) {
                            return 'Please replace placeholders with actual values';
                          }
                          if (!value.startsWith('mongodb://') &&
                              !value.startsWith('mongodb+srv://')) {
                            return 'Connection string must start with mongodb:// or mongodb+srv://';
                          }
                          return null;
                        },
                      ),

                      if (_connectionStatus != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                _connectionSuccess
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _connectionSuccess
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    _connectionSuccess
                                        ? Colors.green
                                        : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _connectionStatus!,
                                  style: TextStyle(
                                    color:
                                        _connectionSuccess
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isTestingConnection ? null : _testConnection,
                              icon:
                                  _isTestingConnection
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.network_check),
                              label: const Text('Test Connection'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveConnectionString,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save),
                          label: const Text('Save Configuration'),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Help',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'If you encounter connection issues:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              const ListTile(
                                leading: Icon(Icons.security, size: 20),
                                contentPadding: EdgeInsets.zero,
                                minLeadingWidth: 20,
                                title: Text(
                                  'Ensure your MongoDB Atlas cluster has network access enabled for your IP',
                                ),
                                dense: true,
                              ),
                              const ListTile(
                                leading: Icon(Icons.person, size: 20),
                                contentPadding: EdgeInsets.zero,
                                minLeadingWidth: 20,
                                title: Text(
                                  'Verify your database username and password are correct',
                                ),
                                dense: true,
                              ),
                              const ListTile(
                                leading: Icon(Icons.link, size: 20),
                                contentPadding: EdgeInsets.zero,
                                minLeadingWidth: 20,
                                title: Text(
                                  'Try using mongodb:// instead of mongodb+srv:// if you continue to have issues',
                                ),
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Text(
                        'Note: Your MongoDB connection string includes your username and password. It is stored securely on your device.',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall!.color!.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  @override
  void dispose() {
    _connectionStringController.dispose();
    super.dispose();
  }
}
