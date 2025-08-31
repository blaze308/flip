import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProfileWidget extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUser;
  final VoidCallback? onEditProfile;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final bool showFollowButton;

  const UserProfileWidget({
    super.key,
    required this.user,
    this.isCurrentUser = false,
    this.onEditProfile,
    this.onFollow,
    this.onMessage,
    this.showFollowButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(context),
          const SizedBox(height: 16),

          // Stats Row
          _buildStatsRow(context),
          const SizedBox(height: 16),

          // Bio
          if (user.hasBio) _buildBio(context),
          if (user.hasBio) const SizedBox(height: 16),

          // Website
          if (user.hasWebsite) _buildWebsite(context),
          if (user.hasWebsite) const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Row(
      children: [
        // Profile Image
        _buildProfileImage(),
        const SizedBox(width: 16),

        // User Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username with verification badge
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.accountBadge.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      user.accountBadge,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ],
              ),

              // Display Name
              if (user.displayName != user.username) ...[
                const SizedBox(height: 4),
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],

              // Location
              if (user.hasLocation) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        user.location!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4ECDC4), width: 2),
      ),
      child: ClipOval(
        child:
            user.hasProfileImage
                ? Image.network(
                  user.profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => _buildDefaultAvatar(),
                )
                : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF4ECDC4),
      child: Center(
        child: Text(
          user.initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          'Posts',
          UserService.formatFollowerCount(user.postsCount),
        ),
        _buildStatItem(
          'Followers',
          UserService.formatFollowerCount(user.followersCount),
        ),
        _buildStatItem(
          'Following',
          UserService.formatFollowerCount(user.followingCount),
        ),
        _buildStatItem(
          'Likes',
          UserService.formatFollowerCount(user.likesCount),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildBio(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        user.bio!,
        style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildWebsite(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Open website URL
        // You can use url_launcher package here
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4ECDC4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 16, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(
              user.website!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4ECDC4),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isCurrentUser) {
      return _buildCurrentUserButtons(context);
    } else {
      return _buildOtherUserButtons(context);
    }
  }

  Widget _buildCurrentUserButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            // Show share profile options
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  Widget _buildOtherUserButtons(BuildContext context) {
    return Row(
      children: [
        if (showFollowButton) ...[
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onFollow,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Follow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.message_outlined),
            label: const Text('Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            _showMoreOptions(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C3E50),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Options
                _buildOptionTile(
                  icon: Icons.share_outlined,
                  title: 'Share Profile',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle share
                  },
                ),
                _buildOptionTile(
                  icon: Icons.copy_outlined,
                  title: 'Copy Profile Link',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle copy link
                  },
                ),
                _buildOptionTile(
                  icon: Icons.block_outlined,
                  title: 'Block User',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle block
                  },
                  isDestructive: true,
                ),
                _buildOptionTile(
                  icon: Icons.report_outlined,
                  title: 'Report User',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle report
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// Compact user profile widget for lists
class CompactUserProfileWidget extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactUserProfileWidget({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF4ECDC4),
        backgroundImage:
            user.hasProfileImage ? NetworkImage(user.profileImageUrl!) : null,
        child:
            !user.hasProfileImage
                ? Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.accountBadge.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(user.accountBadge, style: const TextStyle(fontSize: 16)),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.displayName != user.username)
            Text(
              user.displayName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          Text(
            '${UserService.formatFollowerCount(user.followersCount)} followers',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
