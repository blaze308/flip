import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';
import '../../services/token_auth_service.dart';
import '../../utils/level_calculator.dart';
import '../../widgets/custom_toaster.dart';
import '../../widgets/gifts_tab.dart';
import '../../widgets/posts_tab.dart';
import '../../widgets/user_badge_widget.dart';
import '../premium/mvp_purchase_screen.dart';
import '../premium/payment_methods_screen.dart';
import '../premium/premium_hub_screen.dart';
import '../premium/wallet_screen_riverpod.dart';
import '../settings/settings_screen.dart';
import 'followers_screen.dart';
import 'profile_edit_screen.dart';

/// Profile screen using the old tab-style layout, wired to new services.
class ProfileTabScreen extends StatefulWidget {
  final String? userId; // null = current user

  const ProfileTabScreen({super.key, this.userId});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  bool _loading = true;
  bool _isTokenInvalid = false;
  bool _isCurrentUser = false;
  late TabController _tabController;

  final List<_Shortcut> _personal = const [
    _Shortcut(label: 'Posts', icon: Icons.grid_on, type: _ShortcutType.posts),
    _Shortcut(label: 'Gifts', icon: Icons.card_giftcard, type: _ShortcutType.gifts),
    _Shortcut(label: 'Followers', icon: Icons.people_alt_outlined, type: _ShortcutType.followers),
    _Shortcut(label: 'Following', icon: Icons.person_outline, type: _ShortcutType.following),
  ];

  final List<_Shortcut> _privileges = const [
    _Shortcut(label: 'MVP', icon: Icons.workspace_premium, type: _ShortcutType.mvp),
    _Shortcut(label: 'Premium Hub', icon: Icons.auto_awesome, type: _ShortcutType.premiumHub),
    _Shortcut(label: 'Wallet', icon: Icons.account_balance_wallet, type: _ShortcutType.wallet),
    _Shortcut(label: 'Settings', icon: Icons.settings, type: _ShortcutType.settings),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _isTokenInvalid = false;
    });
    try {
      final currentUser = TokenAuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _loading = false;
          _isTokenInvalid = true;
        });
        return;
      }
      _isCurrentUser = widget.userId == null || widget.userId == currentUser.id;
      final user = _isCurrentUser
          ? await ProfileService.getMyProfile()
          : await ProfileService.getUserProfile(widget.userId!);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToasterService.showError(context, 'Failed to load profile');
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null || _isCurrentUser) return;
    final result = await ProfileService.toggleFollow(_user!.id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _user = _user!.copyWith(
          isFollowing: result['isFollowing'] as bool,
          followersCount: result['followersCount'] as int,
        );
      });
      ToasterService.showSuccess(
        context,
        result['isFollowing'] ? 'Following' : 'Unfollowed',
      );
    } else {
      ToasterService.showError(context, result['message'] ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : TokenAuthService.currentUser == null || _isTokenInvalid
              ? _buildNotLoggedIn()
              : _user == null
                  ? _buildError()
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _headerCard(),
                            const SizedBox(height: 12),
                            _actionButtons(),
                            const SizedBox(height: 12),
                            _statsRow(),
                            const SizedBox(height: 16),
                            _premiumRow(),
                            const SizedBox(height: 16),
                            _walletRow(),
                            const SizedBox(height: 16),
                            _bioSection(),
                            _interestsSection(),
                            const SizedBox(height: 16),
                            _mvpPerksSection(),
                            const SizedBox(height: 16),
                            _gamificationSection(),
                            const SizedBox(height: 16),
                            if (_isCurrentUser) _paymentMethodsSection(),
                            const SizedBox(height: 20),
                            _sectionTitle('Personal'),
                            const SizedBox(height: 10),
                            _shortcutGrid(_personal),
                            const SizedBox(height: 20),
                            _sectionTitle('Privileges'),
                            const SizedBox(height: 10),
                            _shortcutGrid(_privileges),
                            const SizedBox(height: 20),
                            _tabsSection(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text('Profile unavailable', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Not Logged In',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please log in to view your profile.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    final user = _user!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _avatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'ID: ${user.id.substring(0, 8)}...',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.id));
                        ToasterService.showSuccess(context, 'User ID copied');
                      },
                      child: const Icon(Icons.copy, color: Colors.grey, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                UserBadgesRow(
                  user: user,
                  badgeSize: 22,
                  showLabels: true,
                  alignment: MainAxisAlignment.start,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(UserModel user) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF05070E), width: 4),
      ),
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF0B1020),
        backgroundImage: user.profileImageUrl != null
            ? CachedNetworkImageProvider(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null
            ? Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Widget _actionButtons() {
    if (_isCurrentUser) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileEditScreen(user: _user!),
                  ),
                );
                if (result == true) _load();
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _user!.isFollowing ? Colors.transparent : const Color(0xFF4ECDC4),
                foregroundColor: _user!.isFollowing ? const Color(0xFF4ECDC4) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: _user!.isFollowing
                      ? const BorderSide(color: Color(0xFF4ECDC4), width: 1.5)
                      : BorderSide.none,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              onPressed: _toggleFollow,
              child: Text(_user!.isFollowing ? 'Following' : 'Follow'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4ECDC4),
              side: const BorderSide(color: Color(0xFF4ECDC4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onPressed: () {
              ToasterService.showInfo(context, 'Message feature coming soon');
            },
            child: const Icon(Icons.message_outlined, size: 18),
          ),
        ],
      );
    }
  }

  Widget _statsRow() {
    final user = _user!;
    final stats = [
      _Stat(icon: Icons.image_outlined, label: 'Posts', value: user.postsCount),
      _Stat(
        icon: Icons.people_outline,
        label: 'Followers',
        value: user.followersCount,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowersScreen(userId: user.id, isFollowers: true),
            ),
          );
        },
      ),
      _Stat(
        icon: Icons.person_add_outlined,
        label: 'Following',
        value: user.followingCount,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowersScreen(userId: user.id, isFollowers: false),
            ),
          );
        },
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats
            .map(
              (s) => GestureDetector(
                onTap: s.onTap,
                child: Column(
                  children: [
                    Icon(s.icon, color: const Color(0xFF4ECDC4), size: 22),
                    const SizedBox(height: 6),
                    Text(
                      s.value.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _premiumRow() {
    return Row(
      children: [
        Expanded(
          child: _premiumCard(
            title: 'MVP',
            subtitle: 'Exclusive privileges',
            colors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MvpPurchaseScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _premiumCard(
            title: 'Premium Hub',
            subtitle: 'VIP, Guardian, Wallet',
            colors: const [Color(0xFF0DB9D7), Color(0xFF00BFA5)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumHubScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _premiumCard({
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _walletRow() {
    final user = _user!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreenRiverpod()),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Wallet', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFF4ECDC4), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${user.coins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 46,
            color: Colors.grey.withOpacity(0.3),
          ),
          Expanded(
            child: TextButton(
              onPressed: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Diamonds', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.diamond, color: Colors.cyan, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${user.diamonds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bioSection() {
    final bio = _user!.bio;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            bio,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _interestsSection() {
    final interests = _user!.interests ?? [];
    if (interests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: interests
            .map(
              (interest) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _mvpPerksSection() {
    final perks = [
      'Exclusive social footprint',
      'Level up acceleration',
      'Family privileges',
      'Enhanced presence',
      'Exclusive vehicle',
      'Premium badge/frame',
      'True love indicator',
      'Mini profile background',
      'Status symbol',
      'Exclusive wallpaper',
      'Wealth privileges',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.workspace_premium, color: Color(0xFF9C27B0), size: 20),
              SizedBox(width: 8),
              Text(
                'MVP Privileges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: perks
                .map(
                  (perk) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.4)),
                    ),
                    child: Text(
                      perk,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _gamificationSection() {
    final user = _user!;
    final hasWealth = user.wealthLevel > 0;
    final hasLive = user.liveLevel > 0;
    final hasCoins = user.coins > 0 || user.diamonds > 0;
    if (!hasWealth && !hasLive && !hasCoins) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star, color: Color(0xFF4ECDC4), size: 20),
              SizedBox(width: 8),
              Text(
                'Levels & Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasWealth)
            _levelProgress(
              label: 'Wealth Level',
              level: user.wealthLevel,
              progress: LevelCalculator.calculateWealthProgress(
                user.creditsSent,
                user.wealthLevel,
              ),
              color: Colors.amber,
              icon: Icons.monetization_on,
            ),
          if (hasWealth) const SizedBox(height: 12),
          if (hasLive)
            _levelProgress(
              label: 'Live Level',
              level: user.liveLevel,
              progress: LevelCalculator.calculateLiveProgress(
                user.giftsReceived,
                user.liveLevel,
              ),
              color: Colors.purple,
              icon: Icons.star,
            ),
          if (hasCoins) const SizedBox(height: 12),
          if (hasCoins)
            Row(
              children: [
                if (user.coins > 0)
                  Expanded(
                    child: _rewardCard(
                      icon: Icons.toll,
                      label: 'Coins',
                      value: user.coins.toString(),
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                if (user.coins > 0 && user.diamonds > 0) const SizedBox(width: 10),
                if (user.diamonds > 0)
                  Expanded(
                    child: _rewardCard(
                      icon: Icons.diamond,
                      label: 'Diamonds',
                      value: user.diamonds.toString(),
                      color: Colors.cyan,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _levelProgress({
    required String label,
    required int level,
    required Map<String, dynamic> progress,
    required Color color,
    required IconData icon,
  }) {
    final isMax = progress['isMaxLevel'] as bool;
    final progressValue = progress['progress'] as double;
    final current = progress['current'] as int;
    final required = progress['required'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              '$label $level',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              isMax ? 'MAX' : 'Next: Lv.${progress['nextLevel']}',
              style: TextStyle(color: isMax ? Colors.amber : Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progressValue,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.5), color],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        if (!isMax)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${LevelCalculator.formatNumber(current)} / ${LevelCalculator.formatNumber(required)}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _rewardCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _paymentMethodsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PaymentMethodsScreen(user: _user!)),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF4ECDC4).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.payment, color: Color(0xFF4ECDC4)),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Manage your payment options',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _shortcutGrid(List<_Shortcut> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.05)),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: items
            .map(
              (item) => GestureDetector(
                onTap: () => _handleShortcut(item),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Icon(item.icon, color: const Color(0xFF4ECDC4), size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tabsSection() {
    final user = _user!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF4ECDC4),
            labelColor: const Color(0xFF4ECDC4),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Posts'),
              Tab(text: 'Gifts'),
              Tab(text: 'About'),
            ],
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                PostsTab(userId: user.id),
                GiftsTab(userId: user.id, isCurrentUser: _isCurrentUser),
                _aboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutTab() {
    final user = _user!;
    final tiles = <Widget>[];
    void addTile(String label, String? value, IconData icon) {
      if (value == null || value.isEmpty) return;
      tiles.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1324),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4ECDC4), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    addTile('Occupation', user.occupation, Icons.work_outline);
    addTile('Website', user.website, Icons.language);
    addTile('Email', user.email, Icons.email_outlined);
    addTile('Gender', user.gender, Icons.person_outline);
    if (user.createdAt != null) {
      addTile(
        'Joined',
        '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}',
        Icons.calendar_today_outlined,
      );
    }
    if (tiles.isEmpty) {
      return const Center(
        child: Text('No about info', style: TextStyle(color: Colors.white54)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: tiles),
    );
  }

  void _handleShortcut(_Shortcut item) {
    final user = _user;
    if (user == null) return;
    switch (item.type) {
      case _ShortcutType.posts:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostsTab(userId: user.id)),
        );
        break;
      case _ShortcutType.gifts:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GiftsTab(userId: user.id, isCurrentUser: _isCurrentUser)),
        );
        break;
      case _ShortcutType.followers:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FollowersScreen(userId: user.id, isFollowers: true),
          ),
        );
        break;
      case _ShortcutType.following:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FollowersScreen(userId: user.id, isFollowers: false),
          ),
        );
        break;
      case _ShortcutType.mvp:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MvpPurchaseScreen()));
        break;
      case _ShortcutType.premiumHub:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumHubScreen()));
        break;
      case _ShortcutType.wallet:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreenRiverpod()));
        break;
      case _ShortcutType.settings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  _Stat({required this.icon, required this.label, required this.value, this.onTap});
}

class _Shortcut {
  final String label;
  final IconData icon;
  final _ShortcutType type;

  const _Shortcut({required this.label, required this.icon, required this.type});
}

enum _ShortcutType {
  posts,
  gifts,
  followers,
  following,
  mvp,
  premiumHub,
  wallet,
  settings,
}

