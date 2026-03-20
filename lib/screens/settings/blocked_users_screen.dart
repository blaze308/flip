import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_toaster.dart';

/// Blocked Users Screen
/// Lists users you have blocked with option to unblock
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserModel> _blockedUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await UserService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _unblockUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Unblock user?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${user.displayName.isNotEmpty ? user.displayName : "This user"} will be able to see your content and contact you again.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock', style: TextStyle(color: Color(0xFF4ECDC4))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await UserService.unblockUser(user.id);
      if (mounted) {
        setState(() => _blockedUsers.removeWhere((u) => u.id == user.id));
        ToasterService.showSuccess(context, 'User unblocked');
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(context, 'Failed to unblock: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Blocked Users', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load blocked users',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadBlockedUsers,
                        child: const Text('Retry', style: TextStyle(color: Color(0xFF4ECDC4))),
                      ),
                    ],
                  ),
                )
              : _blockedUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, size: 80, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'No blocked users',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Users you block will appear here',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBlockedUsers,
                      color: const Color(0xFF4ECDC4),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _blockedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _blockedUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1D1E33),
                              backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(user.profileImageUrl!)
                                  : null,
                              child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                                  ? const Icon(Icons.person, color: Color(0xFF4ECDC4))
                                  : null,
                            ),
                            title: Text(
                              user.displayName.isNotEmpty ? user.displayName : 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: user.username.isNotEmpty
                                ? Text(
                                    '@${user.username}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  )
                                : null,
                            trailing: TextButton(
                              onPressed: () => _unblockUser(user),
                              child: const Text('Unblock', style: TextStyle(color: Color(0xFF4ECDC4))),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
