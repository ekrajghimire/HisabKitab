import 'package:flutter/material.dart';
import '../services/mongo_db_service.dart';
import '../services/dual_storage_service.dart';

class MongoDBStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final bool showConnectionString;

  const MongoDBStatusIndicator({
    Key? key,
    this.showLabel = true,
    this.showConnectionString = false,
  }) : super(key: key);

  @override
  State<MongoDBStatusIndicator> createState() => _MongoDBStatusIndicatorState();
}

class _MongoDBStatusIndicatorState extends State<MongoDBStatusIndicator> {
  bool _isConnected = false;
  bool _isLoading = true;
  String? _connectionString;
  int? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if MongoDB is configured and connected
      final isOnline = await DualStorageService.instance.isOnline;

      // Get last sync time
      final lastSync = await DualStorageService.instance.getLastSyncTime();

      // Get connection string if needed
      String? connString;
      if (widget.showConnectionString) {
        final hasValid =
            await MongoDBService.instance.hasValidConnectionString();
        if (hasValid) {
          connString = await MongoDBService.instance.getConnectionString();

          // Mask the password for security
          if (connString.contains(':')) {
            final parts = connString.split('@');
            if (parts.length > 1) {
              final credentials = parts[0].split('://');
              if (credentials.length > 1) {
                final protocol = credentials[0];
                final userPass = credentials[1].split(':');
                if (userPass.length > 1) {
                  final username = userPass[0];
                  connString = '$protocol://$username:******@${parts[1]}';
                }
              }
            }
          }
        } else {
          connString = 'Not configured';
        }
      }

      if (mounted) {
        setState(() {
          _isConnected = isOnline;
          _isLoading = false;
          _connectionString = connString;
          _lastSyncTime = lastSync;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    }
  }

  String _formatLastSyncTime() {
    if (_lastSyncTime == null) {
      return 'Never synced';
    }

    final syncDate = DateTime.fromMillisecondsSinceEpoch(_lastSyncTime!);
    final now = DateTime.now();
    final difference = now.difference(syncDate);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${syncDate.year}-${syncDate.month.toString().padLeft(2, '0')}-${syncDate.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 6),
            Text(
              'Checking MongoDB...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.5),
              ),
            ),
          ],
        ],
      );
    }

    return InkWell(
      onTap: _checkConnectionStatus,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(width: 6),
              Text(
                _isConnected ? 'MongoDB: Online' : 'MongoDB: Offline',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _isConnected
                          ? Theme.of(context).colorScheme.onBackground
                          : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_isConnected && _lastSyncTime != null) ...[
              const SizedBox(width: 6),
              Text(
                '• Last sync: ${_formatLastSyncTime()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
            if (widget.showConnectionString && _connectionString != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _connectionString!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
