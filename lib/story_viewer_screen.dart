import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import 'models/story_model.dart';
import 'providers/app_providers.dart';
import 'services/story_service.dart';
import 'services/token_auth_service.dart';
import 'services/contextual_auth_service.dart';
import 'widgets/custom_toaster.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<StoryFeedItem> storyFeedItems;
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoryViewerScreen({
    Key? key,
    required this.storyFeedItems,
    this.initialUserIndex = 0,
    this.initialStoryIndex = 0,
  }) : super(key: key);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin {
  late PageController _userPageController;
  late AnimationController _progressController;
  late AnimationController _overlayController;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  Timer? _storyTimer;
  bool _isOverlayVisible = true;
  bool _isPaused = false;
  bool _isLoading = false;

  // Story durations (in seconds)
  static const int _textStoryDuration = 5;
  static const int _imageStoryDuration = 5;
  static const int _audioStoryDuration = 30;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _currentStoryIndex = widget.initialStoryIndex;

    _userPageController = PageController(initialPage: _currentUserIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _textStoryDuration),
    );
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    // Add listener for progress bar updates
    _progressController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _initializeStory();
  }

  @override
  void dispose() {
    _userPageController.dispose();
    _progressController.dispose();
    _overlayController.dispose();
    _videoController?.dispose();
    _audioPlayer?.dispose();
    _storyTimer?.cancel();
    super.dispose();
  }

  void _initializeStory() {
    final currentUser = widget.storyFeedItems[_currentUserIndex];
    if (_currentStoryIndex >= currentUser.stories.length) {
      _currentStoryIndex = 0;
    }

    final currentStory = currentUser.stories[_currentStoryIndex];
    _setupStoryTimer(currentStory);
    _markStoryAsViewed(currentStory);
  }

  void _setupStoryTimer(StoryModel story) {
    _progressController.stop();
    _progressController.reset();
    _videoController?.dispose();
    _videoController = null;
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _storyTimer?.cancel();

    int duration = _textStoryDuration;

    switch (story.mediaType) {
      case StoryMediaType.text:
        duration = _textStoryDuration;
        _startTimer(duration);
        break;
      case StoryMediaType.image:
        duration = _imageStoryDuration;
        // Preload image before starting timer
        _preloadImageAndStartTimer(story, duration);
        break;
      case StoryMediaType.video:
        _initializeVideo(story);
        return; // Video will handle its own timing
      case StoryMediaType.audio:
        _initializeAudio(story);
        return; // Audio will handle its own timing
    }
  }

  void _initializeAudio(StoryModel story) async {
    if (story.mediaUrl == null) {
      _startTimer(_audioStoryDuration);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Dispose previous audio player
      await _audioPlayer?.dispose();

      // Create new audio player
      _audioPlayer = AudioPlayer();

      // Load and play audio
      await _audioPlayer!.play(UrlSource(story.mediaUrl!));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Get audio duration for progress bar
      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted) {
          _progressController.duration = duration;
        }
      });

      // Update progress bar continuously as audio plays
      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted && _audioPlayer!.state == PlayerState.playing) {
          final duration = _progressController.duration?.inMilliseconds ?? 1;
          final progress = position.inMilliseconds / duration;
          _progressController.value = progress.clamp(0.0, 1.0);
        }
      });

      // Handle playback completion
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted && !_isPaused) {
          _nextStory();
        }
      });

      // Handle errors
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.stopped && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Audio story error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Fallback to timer if audio fails
        _startTimer(_audioStoryDuration);
      }
    }
  }

  void _startTimer(int duration) {
    _progressController.duration = Duration(seconds: duration);

    if (!_isPaused) {
      _progressController.forward().then((_) {
        if (mounted && !_isPaused) {
          _nextStory();
        }
      });
    }
  }

  void _preloadImageAndStartTimer(StoryModel story, int duration) async {
    if (story.mediaUrl == null) {
      _startTimer(duration);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final imageUrl = _getFullImageUrl(story.mediaUrl);
    final image = NetworkImage(imageUrl);

    // Preload the image
    try {
      await precacheImage(image, context);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startTimer(duration);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startTimer(duration);
      }
    }
  }

  String _getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';
    if (relativeUrl.startsWith('http')) return relativeUrl;

    // Add the base URL for relative paths
    const baseUrl = 'https://flip-backend-mnpg.onrender.com';
    return '$baseUrl$relativeUrl';
  }

  void _initializeVideo(StoryModel story) {
    if (story.mediaUrl == null) return;

    setState(() {
      _isLoading = true;
    });

    _videoController = VideoPlayerController.networkUrl(
        Uri.parse(story.mediaUrl!),
      )
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              final duration = _videoController!.value.duration;
              _progressController.duration = duration;

              if (!_isPaused) {
                _videoController!.play();
                _progressController.forward().then((_) {
                  if (mounted && !_isPaused) {
                    _nextStory();
                  }
                });
              }
            }
          })
          .catchError((error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              context.showErrorToaster('Failed to load video');
            }
          });
  }

  void _markStoryAsViewed(StoryModel story) {
    // Only mark as viewed if user is authenticated
    if (TokenAuthService.isAuthenticated) {
      StoryService.markStoryAsViewed(story.id);
    }
  }

  void _nextStory() {
    final currentUser = widget.storyFeedItems[_currentUserIndex];

    if (_currentStoryIndex < currentUser.stories.length - 1) {
      // Next story for current user
      setState(() {
        _currentStoryIndex++;
      });
      _initializeStory();
    } else {
      // Next user
      _nextUser();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      // Previous story for current user
      setState(() {
        _currentStoryIndex--;
      });
      _initializeStory();
    } else {
      // Previous user
      _previousUser();
    }
  }

  void _nextUser() {
    if (_currentUserIndex < widget.storyFeedItems.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _userPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeStory();
    } else {
      // End of stories
      Navigator.of(context).pop();
    }
  }

  void _previousUser() {
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex =
            widget.storyFeedItems[_currentUserIndex].stories.length - 1;
      });
      _userPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeStory();
    } else {
      // Beginning of stories
      Navigator.of(context).pop();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _progressController.stop();
      _videoController?.pause();
    } else {
      _progressController.forward();
      _videoController?.play();
    }
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });

    if (_isOverlayVisible) {
      _overlayController.forward();
    } else {
      _overlayController.reverse();
    }
  }

  // Check if current user is the story owner
  bool _isCurrentUserStoryOwner(StoryModel story) {
    if (!TokenAuthService.isAuthenticated) return false;
    final currentUser = TokenAuthService.currentUser;
    return currentUser?.id == story.userId;
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(StoryModel story) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Delete Story',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this story? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      await _deleteStory(story);
    }
  }

  // Delete the story
  Future<void> _deleteStory(StoryModel story) async {
    try {
      await StoryService.deleteStory(story.id);

      // Refresh stories provider to sync with backend
      ref.read(storiesProvider.notifier).refresh();

      context.showSuccessToaster('Story deleted successfully');

      // Remove story from the current user's stories
      final currentUser = widget.storyFeedItems[_currentUserIndex];
      currentUser.stories.removeWhere((s) => s.id == story.id);

      // If no more stories for this user, move to next user or exit
      if (currentUser.stories.isEmpty) {
        if (_currentUserIndex < widget.storyFeedItems.length - 1) {
          _nextUser();
        } else {
          Navigator.of(context).pop();
        }
      } else {
        // Adjust story index if needed
        if (_currentStoryIndex >= currentUser.stories.length) {
          _currentStoryIndex = currentUser.stories.length - 1;
        }
        _initializeStory();
      }
    } catch (e) {
      context.showErrorToaster('Failed to delete story');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main story content
            PageView.builder(
              controller: _userPageController,
              itemCount: widget.storyFeedItems.length,
              onPageChanged: (index) {
                setState(() {
                  _currentUserIndex = index;
                  _currentStoryIndex = 0;
                });
                _initializeStory();
              },
              itemBuilder: (context, userIndex) {
                final user = widget.storyFeedItems[userIndex];
                if (userIndex == _currentUserIndex &&
                    _currentStoryIndex < user.stories.length) {
                  return _buildStoryContent(user.stories[_currentStoryIndex]);
                }
                return Container(); // Placeholder for other users
              },
            ),

            // Tap areas for navigation
            Row(
              children: [
                // Left tap area (previous)
                Expanded(
                  child: GestureDetector(
                    onTap: _previousStory,
                    onLongPress: _togglePause,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Right tap area (next)
                Expanded(
                  child: GestureDetector(
                    onTap: _nextStory,
                    onLongPress: _togglePause,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),

            // Overlay with progress and controls
            AnimatedBuilder(
              animation: _overlayController,
              builder: (context, child) {
                return Opacity(
                  opacity: _overlayController.value,
                  child: _buildOverlay(),
                );
              },
            ),

            // Center tap area for overlay toggle
            Center(
              child: GestureDetector(
                onTap: _toggleOverlay,
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    switch (story.mediaType) {
      case StoryMediaType.text:
        return _buildTextStory(story);
      case StoryMediaType.image:
        return _buildImageStory(story);
      case StoryMediaType.video:
        return _buildVideoStory(story);
      case StoryMediaType.audio:
        return _buildAudioStory(story);
    }
  }

  Widget _buildTextStory(StoryModel story) {
    final textStyle = story.textStyle;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color:
            textStyle != null
                ? textStyle.backgroundColor
                : const Color(0xFF4ECDC4),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            story.textContent ?? '',
            style: TextStyle(
              color: textStyle != null ? textStyle.textColor : Colors.white,
              fontSize: textStyle?.fontSize ?? 24.0,
              fontWeight: textStyle?.fontWeight ?? FontWeight.normal,
              fontFamily: textStyle?.fontFamily ?? 'Roboto',
            ),
            textAlign: textStyle?.textAlign ?? TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildImageStory(StoryModel story) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Image.network(
        _getFullImageUrl(story.mediaUrl ?? ''),
        fit: BoxFit.contain,
        headers: const {'User-Agent': 'Mozilla/5.0 (compatible; Flutter app)'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Color(0xFF4ECDC4),
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('📖 Image loading error: $error');
          print('📖 Image URL: ${story.mediaUrl}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'URL: ${_getFullImageUrl(story.mediaUrl ?? 'No URL')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoStory(StoryModel story) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Center(
        child:
            _isLoading
                ? const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Color(0xFF4ECDC4),
                    strokeWidth: 3,
                  ),
                )
                : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildAudioStory(StoryModel story) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF39C12), Color(0xFFE67E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated audio visualizer
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _audioPlayer?.state == PlayerState.playing
                          ? Icons.volume_up
                          : Icons.audiotrack,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                );
              },
              onEnd: () {
                // Repeat animation
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 32),
            Text(
              _audioPlayer?.state == PlayerState.playing
                  ? 'Now Playing...'
                  : 'Audio Story',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (story.caption?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  story.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final currentUser = widget.storyFeedItems[_currentUserIndex];
    final currentStory = currentUser.stories[_currentStoryIndex];

    return Column(
      children: [
        // Progress indicators
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: List.generate(
              currentUser.stories.length,
              (index) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(
                    right: index < currentUser.stories.length - 1 ? 4 : 0,
                  ),
                  child: LinearProgressIndicator(
                    value:
                        index < _currentStoryIndex
                            ? 1.0
                            : index == _currentStoryIndex
                            ? _progressController.value
                            : 0.0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // User info and controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              // User avatar with border
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      currentUser.userAvatar?.isNotEmpty == true
                          ? NetworkImage(
                            _getFullImageUrl(currentUser.userAvatar!),
                          )
                          : null,
                  backgroundColor: const Color(0xFF4ECDC4),
                  child:
                      currentUser.userAvatar?.isEmpty != false
                          ? Text(
                            currentUser.username.isNotEmpty
                                ? currentUser.username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                          : null,
                ),
              ),
              const SizedBox(width: 12),

              // Username and timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTimestamp(currentStory.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button (only for story owner)
              if (_isCurrentUserStoryOwner(currentStory)) ...[
                IconButton(
                  onPressed: () => _showDeleteConfirmation(currentStory),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],

              // Pause/Play button
              IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
              ),

              // Close button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Reactions removed for now

        // Caption
        if (currentStory.caption?.isNotEmpty == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              currentStory.caption!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  // Reaction button removed for now

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}
