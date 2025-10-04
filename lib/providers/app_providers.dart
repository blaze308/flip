import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/post_service.dart';
import '../services/story_service.dart';
import '../services/comment_service.dart';
import '../services/token_auth_service.dart';

// Authentication Providers
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier();
});

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, TokenUser?>((ref) {
      return CurrentUserNotifier();
    });

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(TokenAuthService.currentState) {
    // Listen to auth changes
    TokenAuthService.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged(AuthState newState, TokenUser? user) {
    // Delay state update to avoid updating during build phase
    Future.microtask(() {
      if (mounted) {
        state = newState;
      }
    });
  }

  @override
  void dispose() {
    TokenAuthService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}

class CurrentUserNotifier extends StateNotifier<TokenUser?> {
  CurrentUserNotifier() : super(TokenAuthService.currentUser) {
    // Listen to auth changes
    TokenAuthService.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged(AuthState authState, TokenUser? user) {
    // Delay state update to avoid updating during build phase
    Future.microtask(() {
      if (mounted) {
        state = user;
      }
    });
  }

  @override
  void dispose() {
    TokenAuthService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}

// Posts Feed Provider with Caching
final postsProvider =
    StateNotifierProvider<PostsNotifier, AsyncValue<List<PostModel>>>((ref) {
      return PostsNotifier(ref);
    });

class PostsNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  PostsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadPosts();
  }

  final Ref ref;
  List<PostModel> _posts = [];
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadPosts() async {
    // Check cache first
    if (_posts.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_posts);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();
      final result = await PostService.getFeed();

      _posts = result.posts;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(_posts);

      // Preload comments for each post for better UX (in background)
      _preloadComments(_posts);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  void _preloadComments(List<PostModel> posts) {
    // Preload comments in background for instant display
    for (final post in posts) {
      CommentService.getComments(post.id, page: 1, limit: 10)
          .then((_) {
            print('📝 PostsNotifier: Preloaded comments for post ${post.id}');
          })
          .catchError((e) {
            print('📝 PostsNotifier: Failed to preload comments: $e');
          });
    }
  }

  Future<void> refresh() async {
    _lastFetch = null; // Force refresh
    await _loadPosts();
  }

  Future<void> toggleLike(String postId) async {
    try {
      // Optimistic update
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final newLikeState = !post.isLiked;
        final newLikeCount = newLikeState ? post.likes + 1 : post.likes - 1;

        _posts[postIndex] = post.copyWith(
          isLiked: newLikeState,
          likes: newLikeCount,
        );
        state = AsyncValue.data([..._posts]);

        // Make API call
        await PostService.toggleLike(postId);
      }
    } catch (e) {
      // Revert on error
      await refresh();
    }
  }

  Future<void> toggleBookmark(String postId) async {
    try {
      // Optimistic update
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        _posts[postIndex] = post.copyWith(isBookmarked: !post.isBookmarked);
        state = AsyncValue.data([..._posts]);

        // Make API call
        await PostService.toggleBookmark(postId);
      }
    } catch (e) {
      // Revert on error
      await refresh();
    }
  }

  void addNewPost(PostModel post) {
    _posts.insert(0, post);
    state = AsyncValue.data([..._posts]);
  }
}

// Stories Provider with Caching
final storiesProvider =
    StateNotifierProvider<StoriesNotifier, AsyncValue<List<StoryFeedItem>>>((
      ref,
    ) {
      return StoriesNotifier(ref);
    });

class StoriesNotifier extends StateNotifier<AsyncValue<List<StoryFeedItem>>> {
  StoriesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadStories();
  }

  final Ref ref;
  List<StoryFeedItem> _stories = [];
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 3);

  Future<void> _loadStories() async {
    // Check cache first
    if (_stories.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_stories);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();
      final stories = await StoryService.getStoriesFeed();

      _stories = stories;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(_stories);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null; // Force refresh
    await _loadStories();
  }

  void addNewStory(StoryFeedItem story) {
    _stories.insert(0, story);
    state = AsyncValue.data([..._stories]);
  }
}

// App Loading State Provider
final appLoadingProvider = StateProvider<bool>((ref) => false);

// Current Tab Provider
final currentTabProvider = StateProvider<int>((ref) => 0);

// Combined App State Provider
final appStateProvider = Provider<AppState>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);
  final posts = ref.watch(postsProvider);
  final stories = ref.watch(storiesProvider);
  final isLoading = ref.watch(appLoadingProvider);
  final currentTab = ref.watch(currentTabProvider);

  return AppState(
    authState: authState,
    currentUser: currentUser,
    posts: posts,
    stories: stories,
    isLoading: isLoading,
    currentTab: currentTab,
  );
});

class AppState {
  final AuthState authState;
  final TokenUser? currentUser;
  final AsyncValue<List<PostModel>> posts;
  final AsyncValue<List<StoryFeedItem>> stories;
  final bool isLoading;
  final int currentTab;

  const AppState({
    required this.authState,
    required this.currentUser,
    required this.posts,
    required this.stories,
    required this.isLoading,
    required this.currentTab,
  });

  bool get isAuthenticated =>
      authState == AuthState.authenticated && currentUser != null;
  bool get isGuest => !isAuthenticated;
}
