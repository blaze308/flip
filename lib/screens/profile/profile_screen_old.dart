// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import '../../models/user_model.dart';
// import '../../services/profile_service.dart';
// import '../../services/token_auth_service.dart';
// import '../../widgets/custom_toaster.dart';
// import '../../widgets/user_badge_widget.dart';
// import '../../widgets/gifts_tab.dart';
// import '../../widgets/posts_tab.dart';
// import '../../utils/level_calculator.dart';
// import '../../models/premium_package_model.dart';
// import 'profile_edit_screen.dart';
// import 'followers_screen.dart';
// import '../premium/wallet_screen_riverpod.dart';
// import '../settings/settings_screen.dart';
// import '../premium/premium_hub_screen.dart';
// import '../premium/mvp_purchase_screen.dart';
// import '../premium/payment_methods_screen.dart';

// /// Profile Screen - Display user profile with stats
// /// Shows own profile or other users' profiles
// class ProfileScreen extends StatefulWidget {
//   final String? userId; // If null, shows current user's profile

//   const ProfileScreen({super.key, this.userId});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen>
//     with SingleTickerProviderStateMixin {
//   UserModel? _user;
//   bool _isLoading = true;
//   bool _isCurrentUser = false;
//   bool _isTokenInvalid = false; // Track when token is invalid/expired
//   late TabController _tabController;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadProfile();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadProfile() async {
//     setState(() {
//       _isLoading = true;
//       _isTokenInvalid = false; // Reset token invalid flag
//     });

//     try {
//       final currentUser = TokenAuthService.currentUser;

//       // Check if user is authenticated
//       if (currentUser == null) {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//         return;
//       }

//       _isCurrentUser = widget.userId == null || widget.userId == currentUser.id;

//       final UserModel? user =
//           _isCurrentUser
//               ? await ProfileService.getMyProfile()
//               : await ProfileService.getUserProfile(widget.userId!);

//       if (mounted) {
//         setState(() {
//           _user = user;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//           // For any error, show login UI - user likely needs to re-authenticate
//           _isTokenInvalid = true;
//         });
//         // Don't show error toast - we'll show login UI instead
//         print('❌ Profile load error: $e');
//       }
//     }
//   }

//   Future<void> _toggleFollow() async {
//     if (_user == null || _isCurrentUser) return;

//     final result = await ProfileService.toggleFollow(_user!.id);

//     if (result['success'] == true) {
//       setState(() {
//         _user = _user!.copyWith(
//           isFollowing: result['isFollowing'] as bool,
//           followersCount: result['followersCount'] as int,
//         );
//       });

//       if (mounted) {
//         ToasterService.showSuccess(
//           context,
//           result['isFollowing'] ? 'Following' : 'Unfollowed',
//         );
//       }
//     } else {
//       if (mounted) {
//         ToasterService.showError(context, result['message'] ?? 'Failed');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF05070E),
//       body:
//           _isLoading
//               ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
//               )
//               : TokenAuthService.currentUser == null || _isTokenInvalid
//               ? _buildNotLoggedInState()
//               : _user == null
//               ? _buildErrorState()
//               : _buildProfileContent(),
//     );
//   }

//   Widget _buildNotLoggedInState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.account_circle, size: 80, color: Colors.grey),
//           const SizedBox(height: 24),
//           Text(
//             _isTokenInvalid ? 'Session Expired' : 'Not Logged In',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             _isTokenInvalid
//                 ? 'Your session has expired. Please log in again.'
//                 : 'Please log in to view your profile',
//             style: const TextStyle(color: Colors.grey, fontSize: 16),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 32),
//           ElevatedButton(
//             onPressed: () async {
//               // If token is invalid, sign out first
//               if (_isTokenInvalid) {
//                 await TokenAuthService.signOut();
//               }
//               // Navigate to login screen
//               Navigator.pushReplacementNamed(context, '/login');
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF4ECDC4),
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: const Text('Log In', style: TextStyle(fontSize: 18)),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     // If we reach here, it means user is authenticated but profile failed to load
//     // Show login button to re-authenticate
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, size: 64, color: Colors.red),
//           const SizedBox(height: 16),
//           const Text(
//             'Failed to load profile',
//             style: TextStyle(color: Colors.white, fontSize: 18),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Please log in again',
//             style: TextStyle(color: Colors.grey, fontSize: 14),
//           ),
//           const SizedBox(height: 24),
//           ElevatedButton(
//             onPressed: () async {
//               await TokenAuthService.signOut();
//               Navigator.pushReplacementNamed(context, '/login');
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF4ECDC4),
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: const Text('Login', style: TextStyle(fontSize: 18)),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildProfileContent() {
//     final user = _user!;
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildModernHeader(user),
//           const SizedBox(height: 16),
//           _buildModernStatsRow(user),
//           const SizedBox(height: 16),
//           _buildPremiumRow(),
//           const SizedBox(height: 16),
//           _buildWalletRow(user),
//           const SizedBox(height: 20),
//           _buildSectionTitle('Personal'),
//           const SizedBox(height: 10),
//           _buildShortcutGrid(_personalShortcuts(user)),
//           const SizedBox(height: 20),
//           _buildSectionTitle('Privileges'),
//           const SizedBox(height: 10),
//           _buildShortcutGrid(_privilegeShortcuts(user)),
//           const SizedBox(height: 20),
//           _buildSectionTitle('More'),
//           const SizedBox(height: 10),
//           _buildListMenu(user),
//           const SizedBox(height: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return SliverAppBar(
//       expandedHeight: 220,
//       pinned: true,
//       backgroundColor: const Color(0xFF1D1E33),
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back, color: Colors.white),
//         onPressed: () => Navigator.pop(context),
//       ),
//       actions: [
//         if (_isCurrentUser) ...[
//           IconButton(
//             icon: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
//             tooltip: 'Premium Features',
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const PremiumHubScreen(),
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const WalletScreenRiverpod(),
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const SettingsScreen()),
//               );
//             },
//           ),
//         ],
//         if (!_isCurrentUser)
//           IconButton(
//             icon: const Icon(Icons.more_vert, color: Colors.white),
//             onPressed: () {
//               // TODO: Show more options (block, report, etc.)
//             },
//           ),
//       ],
//       flexibleSpace: FlexibleSpaceBar(
//         background: Stack(
//           fit: StackFit.expand,
//           children: [
//             _user!.coverPhotoURL != null
//                 ? CachedNetworkImage(
//                   imageUrl: _user!.coverPhotoURL!,
//                   fit: BoxFit.cover,
//                   placeholder:
//                       (context, url) =>
//                           Container(color: const Color(0xFF1D1E33)),
//                   errorWidget:
//                       (context, url, error) => Container(
//                         color: const Color(0xFF1D1E33),
//                         child: const Icon(
//                           Icons.image,
//                           color: Colors.grey,
//                           size: 48,
//                         ),
//                       ),
//                 )
//                 : Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
//                     ),
//                   ),
//                 ),
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     Colors.black.withOpacity(0.6),
//                     Colors.black.withOpacity(0.0),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProfileHeader() {
//     return Transform.translate(
//       offset: const Offset(0, -40),
//       child: Column(
//         children: [
//           Container(
//             width: 110,
//             height: 110,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               boxShadow: [
//                 BoxShadow(
//                   color: const Color(0xFF4ECDC4).withOpacity(0.3),
//                   blurRadius: 20,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: Container(
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 border: Border.all(color: const Color(0xFF0A0E21), width: 5),
//               ),
//               padding: const EdgeInsets.all(3),
//               child: CircleAvatar(
//                 radius: 50,
//                 backgroundColor: const Color(0xFF1D1E33),
//                 backgroundImage:
//                     _user!.profileImageUrl != null
//                         ? CachedNetworkImageProvider(_user!.profileImageUrl!)
//                         : null,
//                 child:
//                     _user!.profileImageUrl == null
//                         ? Text(
//                           _user!.initials,
//                           style: const TextStyle(
//                             fontSize: 36,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         )
//                         : null,
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             _user!.displayName,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 26,
//               fontWeight: FontWeight.bold,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 6),
//           Text(
//             '@${_user!.username}',
//             style: const TextStyle(
//               color: Color(0xFF4ECDC4),
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 12),
//           GestureDetector(
//             onTap: () {
//               Clipboard.setData(ClipboardData(text: _user!.id));
//               ToasterService.showSuccess(context, 'User ID copied!');
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1D1E33),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.grey[700]!),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'ID: ${_user!.id.substring(0, 8)}...',
//                     style: const TextStyle(color: Colors.grey, fontSize: 12),
//                   ),
//                   const SizedBox(width: 6),
//                   const Icon(Icons.copy, size: 13, color: Colors.grey),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           UserBadgesRow(
//             user: _user!,
//             badgeSize: 28.0,
//             showLabels: true,
//             alignment: MainAxisAlignment.center,
//           ),
//           if (_user!.location != null) ...[
//             const SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(
//                   Icons.location_on,
//                   color: Color(0xFF4ECDC4),
//                   size: 16,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   _user!.location!,
//                   style: const TextStyle(
//                     color: Color(0xFF4ECDC4),
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildStats() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _buildStatCard(
//             icon: Icons.image_outlined,
//             count: _user!.postsCount,
//             label: 'Posts',
//           ),
//           _buildStatCard(
//             icon: Icons.people_outline,
//             count: _user!.followersCount,
//             label: 'Followers',
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (context) =>
//                           FollowersScreen(userId: _user!.id, isFollowers: true),
//                 ),
//               );
//             },
//           ),
//           _buildStatCard(
//             icon: Icons.person_add_outlined,
//             count: _user!.followingCount,
//             label: 'Following',
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (context) => FollowersScreen(
//                         userId: _user!.id,
//                         isFollowers: false,
//                       ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatCard({
//     required IconData icon,
//     required int count,
//     required String label,
//     VoidCallback? onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.03),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.18)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Icon(icon, color: const Color(0xFF4ECDC4), size: 22),
//             const SizedBox(height: 6),
//             Text(
//               count.toString(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               label,
//               style: const TextStyle(color: Colors.grey, fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildGamificationStats() {
//     // Only show if user has any gamification stats
//     if (_user!.wealthLevel == 0 &&
//         _user!.liveLevel == 0 &&
//         _user!.coins == 0 &&
//         _user!.diamonds == 0) {
//       return const SizedBox.shrink();
//     }

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1D1E33),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF4ECDC4).withOpacity(0.1),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.star, color: Color(0xFF4ECDC4), size: 24),
//               const SizedBox(width: 12),
//               const Text(
//                 'Levels & Rewards',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           // Level Progress Bars
//           if (_user!.wealthLevel > 0) ...[
//             _buildLevelProgress(
//               label: 'Wealth Level',
//               level: _user!.wealthLevel,
//               progress: LevelCalculator.calculateWealthProgress(
//                 _user!.creditsSent,
//                 _user!.wealthLevel,
//               ),
//               color: Colors.amber,
//               icon: Icons.monetization_on,
//             ),
//             const SizedBox(height: 16),
//           ],
//           if (_user!.liveLevel > 0) ...[
//             _buildLevelProgress(
//               label: 'Live Level',
//               level: _user!.liveLevel,
//               progress: LevelCalculator.calculateLiveProgress(
//                 _user!.giftsReceived,
//                 _user!.liveLevel,
//               ),
//               color: Colors.purple,
//               icon: Icons.star,
//             ),
//             const SizedBox(height: 16),
//           ],
//           // Currency Display in Grid
//           if (_user!.coins > 0 || _user!.diamonds > 0)
//             Row(
//               children: [
//                 if (_user!.coins > 0)
//                   Expanded(
//                     child: _buildRewardCard(
//                       icon: Icons.toll,
//                       label: 'Coins',
//                       value: _user!.coins.toString(),
//                       color: const Color(0xFFFFD700),
//                     ),
//                   ),
//                 if (_user!.coins > 0 && _user!.diamonds > 0)
//                   const SizedBox(width: 12),
//                 if (_user!.diamonds > 0)
//                   Expanded(
//                     child: _buildRewardCard(
//                       icon: Icons.diamond,
//                       label: 'Diamonds',
//                       value: _user!.diamonds.toString(),
//                       color: Colors.cyan,
//                     ),
//                   ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLevelProgress({
//     required String label,
//     required int level,
//     required Map<String, dynamic> progress,
//     required Color color,
//     required IconData icon,
//   }) {
//     final isMaxLevel = progress['isMaxLevel'] as bool;
//     final progressValue = progress['progress'] as double;
//     final current = progress['current'] as int;
//     final required = progress['required'] as int;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: color, size: 20),
//             const SizedBox(width: 8),
//             Text(
//               '$label $level',
//               style: TextStyle(
//                 color: color,
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const Spacer(),
//             if (!isMaxLevel)
//               Text(
//                 'Next: Lv.${progress['nextLevel']}',
//                 style: const TextStyle(color: Colors.grey, fontSize: 12),
//               )
//             else
//               const Text(
//                 'MAX',
//                 style: TextStyle(
//                   color: Colors.amber,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Stack(
//           children: [
//             Container(
//               height: 8,
//               decoration: BoxDecoration(
//                 color: Colors.grey[800],
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ),
//             FractionallySizedBox(
//               widthFactor: progressValue,
//               child: Container(
//                 height: 8,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [color.withOpacity(0.6), color],
//                   ),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         if (!isMaxLevel)
//           Text(
//             '${LevelCalculator.formatNumber(current)} / ${LevelCalculator.formatNumber(required)}',
//             style: const TextStyle(color: Colors.grey, fontSize: 11),
//           ),
//       ],
//     );
//   }

//   Widget _buildRewardCard({
//     required IconData icon,
//     required String label,
//     required String value,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: color, size: 28),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Column(
//         children: [
//           if (_isCurrentUser) ...[
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: [
//                         BoxShadow(
//                           color: const Color(0xFF4ECDC4).withOpacity(0.3),
//                           blurRadius: 8,
//                           offset: const Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: ElevatedButton(
//                       onPressed: () async {
//                         final result = await Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder:
//                                 (context) => ProfileEditScreen(user: _user!),
//                           ),
//                         );
//                         if (result == true) {
//                           _loadProfile();
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF4ECDC4),
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.edit, size: 18),
//                           SizedBox(width: 8),
//                           Text(
//                             'Edit Profile',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Container(
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                       color: const Color(0xFF4ECDC4),
//                       width: 1.5,
//                     ),
//                   ),
//                   child: IconButton(
//                     icon: const Icon(
//                       Icons.account_balance_wallet,
//                       color: Color(0xFF4ECDC4),
//                       size: 22,
//                     ),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const WalletScreenRiverpod(),
//                         ),
//                       );
//                     },
//                     tooltip: 'Wallet',
//                   ),
//                 ),
//               ],
//             ),
//           ] else ...[
//             Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow:
//                           _user!.isFollowing
//                               ? []
//                               : [
//                                 BoxShadow(
//                                   color: const Color(
//                                     0xFF4ECDC4,
//                                   ).withOpacity(0.3),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                     ),
//                     child: ElevatedButton(
//                       onPressed: _toggleFollow,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor:
//                             _user!.isFollowing
//                                 ? Colors.transparent
//                                 : const Color(0xFF4ECDC4),
//                         foregroundColor:
//                             _user!.isFollowing
//                                 ? const Color(0xFF4ECDC4)
//                                 : Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           side:
//                               _user!.isFollowing
//                                   ? const BorderSide(
//                                     color: Color(0xFF4ECDC4),
//                                     width: 1.5,
//                                   )
//                                   : BorderSide.none,
//                         ),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         _user!.isFollowing ? 'Following' : 'Follow',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Container(
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                       color: const Color(0xFF4ECDC4),
//                       width: 1.5,
//                     ),
//                   ),
//                   child: IconButton(
//                     icon: const Icon(
//                       Icons.message_outlined,
//                       color: Color(0xFF4ECDC4),
//                       size: 22,
//                     ),
//                     onPressed: () {
//                       ToasterService.showInfo(
//                         context,
//                         'Message feature coming soon',
//                       );
//                     },
//                     tooltip: 'Message',
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildBio() {
//     if (_user!.bio == null || _user!.bio!.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: const Color(0xFF1D1E33),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.2)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'About',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               _user!.bio!,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 15,
//                 height: 1.6,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHighlights() {
//     final interests = _user!.interests ?? [];
//     if (interests.isEmpty) return const SizedBox.shrink();

//     return Padding(
//       padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Interests',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children:
//                 interests.map((interest) {
//                   return Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 8,
//                     ),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1D1E33),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                         color: const Color(0xFF4ECDC4).withOpacity(0.4),
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           Icons.favorite,
//                           color: const Color(0xFF4ECDC4),
//                           size: 14,
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           interest,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPremiumShortcuts() {
//     final perks = PremiumPackageModel.getMvpPackages();
//     final bool isMvp = _user?.isMVP ?? false;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Row(
//         children: [
//           Expanded(
//             child: _buildPremiumChip(
//               title: isMvp ? 'MVP Active' : 'Get MVP',
//               subtitle:
//                   isMvp ? '2x XP • premium badge' : 'Unlock 11 privileges',
//               gradient: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
//               icon: Icons.workspace_premium,
//               onTap: () async {
//                 final result = await Navigator.push<bool>(
//                   context,
//                   MaterialPageRoute(builder: (_) => const MvpPurchaseScreen()),
//                 );
//                 if (result == true) {
//                   _loadProfile();
//                 }
//               },
//               trailing:
//                   isMvp && _user?.mvpExpiresAt != null
//                       ? 'Until ${_user!.mvpExpiresAt!.day}/${_user!.mvpExpiresAt!.month}'
//                       : 'From ${perks.first.price} coins',
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: _buildPremiumChip(
//               title: 'Premium Hub',
//               subtitle: 'VIP • Guardian • Wallet',
//               gradient: const [Color(0xFF0DB9D7), Color(0xFF00BFA5)],
//               icon: Icons.auto_awesome,
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => const PremiumHubScreen()),
//                 );
//               },
//               trailing: 'Manage',
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPremiumChip({
//     required String title,
//     required String subtitle,
//     required List<Color> gradient,
//     required IconData icon,
//     required VoidCallback onTap,
//     String? trailing,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(colors: gradient),
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: gradient.last.withOpacity(0.25),
//               blurRadius: 12,
//               offset: const Offset(0, 6),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.12),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(icon, color: Colors.white, size: 20),
//                 ),
//                 const Spacer(),
//                 if (trailing != null)
//                   Text(
//                     trailing,
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Text(
//               title,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               subtitle,
//               style: const TextStyle(color: Colors.white70, fontSize: 13),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMvpPerksSection() {
//     final perks = PremiumPackageModel.getMvpPackages().first.benefits;
//     if (perks.isEmpty) return const SizedBox.shrink();

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: const Color(0xFF0F1324),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: const [
//                 Icon(
//                   Icons.workspace_premium,
//                   color: Color(0xFF9C27B0),
//                   size: 20,
//                 ),
//                 SizedBox(width: 8),
//                 Text(
//                   'MVP Privileges',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Wrap(
//               spacing: 10,
//               runSpacing: 10,
//               children:
//                   perks
//                       .map(
//                         (perk) => Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 8,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFF9C27B0).withOpacity(0.12),
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(
//                               color: const Color(0xFF9C27B0).withOpacity(0.4),
//                             ),
//                           ),
//                           child: Text(
//                             perk,
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       )
//                       .toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTabBar() {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFF0F1328),
//         border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
//       ),
//       child: TabBar(
//         controller: _tabController,
//         indicatorColor: const Color(0xFF4ECDC4),
//         indicatorWeight: 3,
//         labelColor: const Color(0xFF4ECDC4),
//         unselectedLabelColor: Colors.grey[600],
//         labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//         unselectedLabelStyle: const TextStyle(
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//         ),
//         tabs: const [
//           Tab(
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.grid_on, size: 20),
//                 SizedBox(width: 6),
//                 Text('Posts'),
//               ],
//             ),
//           ),
//           Tab(
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.card_giftcard, size: 20),
//                 SizedBox(width: 6),
//                 Text('Gifts'),
//               ],
//             ),
//           ),
//           Tab(
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.info_outline, size: 20),
//                 SizedBox(width: 6),
//                 Text('About'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTabContent() {
//     return TabBarView(
//       controller: _tabController,
//       children: [_buildPostsTab(), _buildGiftsTab(), _buildAboutTab()],
//     );
//   }

//   Widget _buildPostsTab() {
//     return PostsTab(userId: _user!.id);
//   }

//   Widget _buildGiftsTab() {
//     return GiftsTab(userId: _user!.id, isCurrentUser: _isCurrentUser);
//   }

//   Widget _buildAboutTab() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         if (_user!.occupation != null)
//           _buildInfoTile('Occupation', _user!.occupation!),
//         if (_user!.website != null) _buildInfoTile('Website', _user!.website!),
//         if (_user!.email != null) _buildInfoTile('Email', _user!.email!),
//         if (_user!.gender != null) _buildInfoTile('Gender', _user!.gender!),
//         if (_user!.createdAt != null)
//           _buildInfoTile(
//             'Joined',
//             '${_user!.createdAt!.day}/${_user!.createdAt!.month}/${_user!.createdAt!.year}',
//           ),
//       ],
//     );
//   }

//   Widget _buildInfoTile(String label, String value) {
//     final Map<String, IconData> _labelIcons = {
//       'Occupation': Icons.work_outline,
//       'Website': Icons.language,
//       'Email': Icons.email_outlined,
//       'Gender': Icons.person_outline,
//       'Joined': Icons.calendar_today_outlined,
//     };

//     final icon = _labelIcons[label] ?? Icons.info_outline;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1D1E33),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.15)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: const Color(0xFF4ECDC4).withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   value,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 15,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 2,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPaymentMethodsSection() {
//     if (!_isCurrentUser) {
//       return const SizedBox.shrink();
//     }

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1D1E33),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF4ECDC4).withOpacity(0.1),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(16),
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => PaymentMethodsScreen(user: _user!),
//               ),
//             );
//           },
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(10),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF4ECDC4).withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: const Icon(
//                         Icons.payment,
//                         color: Color(0xFF4ECDC4),
//                         size: 24,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Payment Methods',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             'Manage your payment options',
//                             style: TextStyle(
//                               color: Colors.grey[400],
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const Icon(
//                       Icons.arrow_forward_ios,
//                       color: Color(0xFF4ECDC4),
//                       size: 16,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 8,
//                   children: [
//                     _buildPaymentMethodTag('💳 AncientFlip Pay'),
//                     _buildPaymentMethodTag('🔵 Google Pay'),
//                     _buildPaymentMethodTag('🏦 Paystack'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPaymentMethodTag(String label) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xFF4ECDC4).withOpacity(0.15),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           color: Color(0xFF4ECDC4),
//           fontSize: 12,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
//   final Widget child;

//   _ProfileTabBarDelegate({required this.child});

//   @override
//   double get minExtent => 56;

//   @override
//   double get maxExtent => 56;

//   @override
//   Widget build(
//     BuildContext context,
//     double shrinkOffset,
//     bool overlapsContent,
//   ) {
//     return Container(
//       decoration: const BoxDecoration(
//         color: Color(0xFF0F1328),
//         border: Border(bottom: BorderSide(color: Color(0xFF1D1E33))),
//       ),
//       child: child,
//     );
//   }

//   @override
//   bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) {
//     return oldDelegate.child != child;
//   }
// }
