import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/story_service.dart';
import 'models/story_model.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/loading_button.dart';

class CreateTextStoryScreen extends StatefulWidget {
  const CreateTextStoryScreen({Key? key}) : super(key: key);

  @override
  State<CreateTextStoryScreen> createState() => _CreateTextStoryScreenState();
}

class _CreateTextStoryScreenState extends State<CreateTextStoryScreen> {
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
  StoryPrivacyType _privacy = StoryPrivacyType.public;
  bool _allowReplies = true;
  bool _allowReactions = true;
  bool _allowScreenshot = true;

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

  final List<String> _fontFamilies = [
    'Roboto',
    'Arial',
    'Times New Roman',
    'Helvetica',
    'Georgia',
  ];

  @override
  void initState() {
    super.initState();
    _textFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Text Story',
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createStory,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      'Share',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Text input area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Center(
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
                    hintText: 'What\'s on your mind?',
                    hintStyle: TextStyle(color: Colors.white70),
                    counterStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),

          // Styling options
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Background colors
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border:
                                isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : Border.all(color: Colors.grey, width: 1),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Text styling controls
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Font size
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Size',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _fontSize,
                                min: 16,
                                max: 40,
                                divisions: 12,
                                activeColor: const Color(0xFF4ECDC4),
                                onChanged: (value) {
                                  setState(() {
                                    _fontSize = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Text alignment
                        Column(
                          children: [
                            const Text(
                              'Align',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildAlignButton(
                                  Icons.format_align_left,
                                  TextAlign.left,
                                ),
                                _buildAlignButton(
                                  Icons.format_align_center,
                                  TextAlign.center,
                                ),
                                _buildAlignButton(
                                  Icons.format_align_right,
                                  TextAlign.right,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignButton(IconData icon, TextAlign align) {
    final isSelected = _textAlign == align;

    return GestureDetector(
      onTap: () {
        setState(() {
          _textAlign = align;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey[700],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
