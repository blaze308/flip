import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/post_service.dart';
import 'models/post_model.dart';
import 'widgets/custom_toaster.dart';

class CreateTextPostScreen extends StatefulWidget {
  const CreateTextPostScreen({Key? key}) : super(key: key);

  @override
  State<CreateTextPostScreen> createState() => _CreateTextPostScreenState();
}

class _CreateTextPostScreenState extends State<CreateTextPostScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Text styling options
  Color _backgroundColor = const Color(0xFF4ECDC4);
  Color _textColor = Colors.white;
  double _fontSize = 18.0;
  FontWeight _fontWeight = FontWeight.w600;
  TextAlign _textAlign = TextAlign.center;
  String _fontFamily = 'Roboto';

  // Post settings
  bool _isPublic = true;
  bool _isLoading = false;

  // Available colors
  final List<Color> _backgroundColors = [
    const Color(0xFF4ECDC4),
    const Color(0xFF667eea),
    const Color(0xFFf093fb),
    const Color(0xFF4facfe),
    const Color(0xFFa8edea),
    const Color(0xFFffecd2),
    const Color(0xFFfcb69f),
    const Color(0xFF667eea),
    Colors.black,
    Colors.white,
  ];

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    const Color(0xFF333333),
    const Color(0xFF667eea),
    const Color(0xFFf093fb),
    const Color(0xFF4facfe),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Text Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Post',
                      style: TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Text preview area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    maxLength: 2000,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontWeight: _fontWeight,
                      fontFamily: _fontFamily,
                    ),
                    textAlign: _textAlign,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: TextStyle(
                        color: _textColor.withOpacity(0.6),
                        fontSize: _fontSize,
                        fontWeight: _fontWeight,
                        fontFamily: _fontFamily,
                      ),
                      border: InputBorder.none,
                      counterStyle: TextStyle(
                        color: _textColor.withOpacity(0.6),
                      ),
                    ),
                    onChanged: (text) => setState(() {}),
                  ),
                ),
              ),
            ),
          ),

          // Styling options
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Background colors
                      _buildSectionTitle('Background Color'),
                      const SizedBox(height: 10),
                      _buildColorPicker(_backgroundColors, _backgroundColor, (
                        color,
                      ) {
                        setState(() => _backgroundColor = color);
                      }),
                      const SizedBox(height: 20),

                      // Text colors
                      _buildSectionTitle('Text Color'),
                      const SizedBox(height: 10),
                      _buildColorPicker(_textColors, _textColor, (color) {
                        setState(() => _textColor = color);
                      }),
                      const SizedBox(height: 20),

                      // Font size
                      _buildSectionTitle('Font Size'),
                      const SizedBox(height: 10),
                      Slider(
                        value: _fontSize,
                        min: 12.0,
                        max: 32.0,
                        divisions: 20,
                        activeColor: const Color(0xFF4ECDC4),
                        inactiveColor: Colors.grey[600],
                        onChanged: (value) {
                          setState(() => _fontSize = value);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Text alignment
                      _buildSectionTitle('Text Alignment'),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAlignmentButton(
                            Icons.format_align_left,
                            TextAlign.left,
                          ),
                          _buildAlignmentButton(
                            Icons.format_align_center,
                            TextAlign.center,
                          ),
                          _buildAlignmentButton(
                            Icons.format_align_right,
                            TextAlign.right,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Privacy setting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Public Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _isPublic,
                            activeColor: const Color(0xFF4ECDC4),
                            onChanged: (value) {
                              setState(() => _isPublic = value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildColorPicker(
    List<Color> colors,
    Color selectedColor,
    Function(Color) onColorSelected,
  ) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = color == selectedColor;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onColorSelected(color);
            },
            child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlignmentButton(IconData icon, TextAlign alignment) {
    final isSelected = _textAlign == alignment;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _textAlign = alignment);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_textController.text.trim().isEmpty) {
      ToasterService.showError(context, 'Please enter some text for your post');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newPost = await PostService.createPost(
        type: PostType.text,
        content: _textController.text.trim(),
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        fontSize: _fontSize,
        fontWeight: _fontWeight,
        textAlign: _textAlign,
        fontFamily: _fontFamily,
        isPublic: _isPublic,
      );

      if (mounted) {
        ToasterService.showSuccess(context, 'Text post created successfully!');

        // Return the new post to the previous screen
        Navigator.of(context).pop(newPost);
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to create post: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
