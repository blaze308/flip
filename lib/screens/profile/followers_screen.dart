import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';
import '../../widgets/custom_toaster.dart';
import 'profile_screen.dart';

/// Followers/Following Screen - Display list of followers or following users
class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true = followers, false = following

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final List<UserModel> users = widget.isFollowers
          ? await ProfileService.getFollowers()
          : await ProfileService.getFollowing();

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToasterService.showError(context, 'Failed to load users');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        title: Text(
          widget.isFollowers ? 'Followers' : 'Following',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
            )
          : _users.isEmpty
              ? _buildEmptyState()
              : _buildUsersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isFollowers ? Icons.people_outline : Icons.person_add_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isFollowers ? 'No followers yet' : 'Not following anyone yet',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      itemCount: _users.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF4ECDC4),
          backgroundImage: user.profileImageUrl != null
              ? CachedNetworkImageProvider(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null
              ? Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '@${user.username}',
          style: const TextStyle(
            color: Color(0xFF4ECDC4),
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.id),
            ),
          );
        },
      ),
    );
  }
}

