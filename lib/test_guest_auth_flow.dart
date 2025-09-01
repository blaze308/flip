import 'package:flutter/material.dart';
import 'services/token_auth_service.dart';
import 'services/post_service.dart';
import 'services/contextual_auth_service.dart';
import 'widgets/contextual_auth_examples.dart';

/// Test widget to verify contextual authentication flow (TikTok/Instagram pattern)
class TestGuestAuthFlow extends StatefulWidget {
  const TestGuestAuthFlow({super.key});

  @override
  State<TestGuestAuthFlow> createState() => _TestGuestAuthFlowState();
}

class _TestGuestAuthFlowState extends State<TestGuestAuthFlow> {
  bool _isLoadingPosts = false;
  String _postLoadResult = '';
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final shouldShow = await TokenAuthService.shouldShowOnboarding();
    setState(() {
      _showOnboarding = shouldShow;
    });
  }

  Future<void> _testMarkOnboardingCompleted() async {
    await TokenAuthService.markOnboardingCompleted();
    _checkOnboardingStatus();
  }

  Future<void> _testContextualAuth(String feature) async {
    bool result = false;
    switch (feature) {
      case 'post':
        result = await ContextualAuthService.canPost(context);
        break;
      case 'like':
        result = await ContextualAuthService.canLike(context);
        break;
      case 'comment':
        result = await ContextualAuthService.canComment(context);
        break;
      case 'follow':
        result = await ContextualAuthService.canFollow(context);
        break;
      case 'profile':
        result = await ContextualAuthService.canAccessProfile(context);
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature access: ${result ? "Granted" : "Denied"}'),
        backgroundColor: result ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _testLoadPublicPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _postLoadResult = '';
    });

    try {
      final result = await PostService.getFeed(limit: 5);
      setState(() {
        _postLoadResult = 'Success: Loaded ${result.posts.length} posts';
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() {
        _postLoadResult = 'Error: ${e.toString()}';
        _isLoadingPosts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = TokenAuthService.currentUser;
    final isAuthenticated = TokenAuthService.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contextual Auth Test'),
        backgroundColor: const Color(0xFF4ECDC4),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authentication Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Is Authenticated: $isAuthenticated'),
                    Text(
                      'Current User: ${currentUser?.displayName ?? 'Guest'}',
                    ),
                    Text('Show Onboarding: $_showOnboarding'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Onboarding Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Onboarding Flow',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _testMarkOnboardingCompleted,
                      child: const Text('Mark Onboarding Completed'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contextual Auth Tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contextual Auth Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _testContextualAuth('post'),
                          child: const Text('Test Post'),
                        ),
                        ElevatedButton(
                          onPressed: () => _testContextualAuth('like'),
                          child: const Text('Test Like'),
                        ),
                        ElevatedButton(
                          onPressed: () => _testContextualAuth('comment'),
                          child: const Text('Test Comment'),
                        ),
                        ElevatedButton(
                          onPressed: () => _testContextualAuth('follow'),
                          child: const Text('Test Follow'),
                        ),
                        ElevatedButton(
                          onPressed: () => _testContextualAuth('profile'),
                          child: const Text('Test Profile'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Post Loading Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Content Loading',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoadingPosts ? null : _testLoadPublicPosts,
                      child:
                          _isLoadingPosts
                              ? const CircularProgressIndicator()
                              : const Text('Load Posts'),
                    ),
                    if (_postLoadResult.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _postLoadResult,
                        style: TextStyle(
                          color:
                              _postLoadResult.startsWith('Success')
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Example Components
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Example Components',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SmartAuthAwareWidget(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ContextualLikeButton(
                          postId: 'test-post-1',
                          isLiked: false,
                          likeCount: 42,
                          onLikeChanged: () {},
                        ),
                        const SizedBox(width: 16),
                        const ContextualCommentButton(
                          postId: 'test-post-1',
                          commentCount: 12,
                        ),
                        const SizedBox(width: 16),
                        ContextualFollowButton(
                          userId: 'test-user-1',
                          isFollowing: false,
                          onFollowChanged: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Expected Behavior
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expected Behavior (TikTok/Instagram Pattern):',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('✅ Onboarding → Homepage (always)'),
                    const Text(
                      '✅ Content loads immediately (no auth blocking)',
                    ),
                    const Text(
                      '✅ Auth prompts only when features are accessed',
                    ),
                    const Text(
                      '✅ Contextual login modals with feature context',
                    ),
                    const Text('✅ Smart UI states based on auth status'),
                    const Text('✅ No route-based authentication blocking'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const ContextualCreatePostFAB(),
    );
  }
}
