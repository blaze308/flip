import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/story_service.dart';
import '../../models/story_model.dart';
import '../../widgets/custom_toaster.dart';
import '../../providers/app_providers.dart';

class CreateTextStoryScreen extends ConsumerStatefulWidget {
  const CreateTextStoryScreen({super.key});

  @override
  ConsumerState<CreateTextStoryScreen> createState() =>
      _CreateTextStoryScreenState();
}

class _CreateTextStoryScreenState extends ConsumerState<CreateTextStoryScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isLoading = false;

  // Text styling options
  Color _backgroundColor = const Color(0xFF4ECDC4);
  Color _textColor = Colors.white;
  String _fontFamily = 'Roboto';
  double _fontSize = 24.0;
  FontWeight _fontWeight = FontWeight.normal;
  TextAlign _textAlign = TextAlign.center;

  // Privacy settings
  final StoryPrivacyType _privacy = StoryPrivacyType.public;
  final bool _allowReplies = true;
  final bool _allowReactions = true;
  final bool _allowScreenshot = true;

  final List<Color> _backgroundColors = [
    const Color(0xFF4ECDC4),
    const Color(0xFFFF6B6B),
    const Color(0xFF9B59B6),
    const Color(0xFFF39C12),
    const Color(0xFF2ECC71),
    const Color(0xFF3498DB),
    const Color(0xFFE74C3C),
    const Color(0xFF1ABC9C),
    Colors.black,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _textFocusNode.requestFocus();
    // Listen to text changes to update character count
    _textController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _createStory() async {
    if (_textController.text.trim().isEmpty) {
      context.showErrorToaster('Please enter some text for your story');
      return;
    }

    if (_textController.text.trim().length > 500) {
      context.showErrorToaster('Story text cannot exceed 500 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StoryService.createTextStory(
        textContent: _textController.text.trim(),
        privacy: _privacy,
        allowReplies: _allowReplies,
        allowReactions: _allowReactions,
        allowScreenshot: _allowScreenshot,
        textStyle: StoryTextStyle(
          backgroundColor: _backgroundColor,
          textColor: _textColor,
          fontFamily: _fontFamily,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
          textAlign: _textAlign,
        ),
      );

      if (result.success && mounted) {
        // Refresh stories to show the new one
        ref.read(storiesProvider.notifier).refresh();

        context.showSuccessToaster('Story created successfully!');
        Navigator.of(context).pop();
        Navigator.of(context).pop(); // Go back to home screen
      } else if (mounted) {
        context.showErrorToaster(result.message.toString());
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster('Failed to create story: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Main content - Text input area
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 100,
              ),
              child: TextField(
                controller: _textController,
                focusNode: _textFocusNode,
                maxLines: null,
                maxLength: 500,
                textAlign: _textAlign,
                style: TextStyle(
                  color: _textColor,
                  fontSize: _fontSize,
                  fontWeight: _fontWeight,
                  fontFamily: _fontFamily,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your story...',
                  hintStyle: TextStyle(color: Colors.white70),
                  counterText: '',
                ),
              ),
            ),
          ),

          // Top bar with controls (like Instagram/WhatsApp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(178), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  // Header with close and share
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: _textColor, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        // Character count
                        Text(
                          '${_textController.text.length}/500',
                          style: TextStyle(
                            color: _textColor.withAlpha(204),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Share button
                        Material(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: _isLoading ? null : _createStory,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text(
                                        'Share',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  // Background color picker
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _backgroundColors.length,
                      itemBuilder: (context, index) {
                        final color = _backgroundColors[index];
                        final isSelected = color == _backgroundColor;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _backgroundColor = color;
                              // Auto-adjust text color for contrast
                              _textColor =
                                  color == Colors.white ||
                                          color == const Color(0xFFF39C12) ||
                                          color == const Color(0xFF2ECC71)
                                      ? Colors.black
                                      : Colors.white;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      )
                                      : null,
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: Colors.white.withAlpha(128),
                                          blurRadius: 8,
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Bottom toolbar with text controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                bottom: 24,
                top: 16,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(178), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Font size control
                  _buildToolButton(
                    icon: Icons.text_fields,
                    label: '${_fontSize.toInt()}',
                    onTap: () {
                      setState(() {
                        if (_fontSize < 40) {
                          _fontSize += 4;
                        } else {
                          _fontSize = 16;
                        }
                      });
                    },
                  ),

                  // Text alignment
                  _buildToolButton(
                    icon:
                        _textAlign == TextAlign.left
                            ? Icons.format_align_left
                            : _textAlign == TextAlign.center
                            ? Icons.format_align_center
                            : Icons.format_align_right,
                    label: '',
                    onTap: () {
                      setState(() {
                        if (_textAlign == TextAlign.left) {
                          _textAlign = TextAlign.center;
                        } else if (_textAlign == TextAlign.center) {
                          _textAlign = TextAlign.right;
                        } else {
                          _textAlign = TextAlign.left;
                        }
                      });
                    },
                  ),

                  // Font weight
                  _buildToolButton(
                    icon: Icons.format_bold,
                    label: '',
                    isActive: _fontWeight == FontWeight.bold,
                    onTap: () {
                      setState(() {
                        _fontWeight =
                            _fontWeight == FontWeight.normal
                                ? FontWeight.bold
                                : FontWeight.normal;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive ? const Color(0xFF4ECDC4) : Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
