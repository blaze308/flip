import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// WhatsApp-style modern image preview with drawing and text tools
class ModernImagePreview extends StatefulWidget {
  final File imageFile;
  final Function(File, String) onSend; // onSend(file, caption)
  final VoidCallback onCancel;
  final String? recipientName; // Optional recipient name

  const ModernImagePreview({
    super.key,
    required this.imageFile,
    required this.onSend,
    required this.onCancel,
    this.recipientName,
  });

  @override
  State<ModernImagePreview> createState() => _ModernImagePreviewState();
}

class _ModernImagePreviewState extends State<ModernImagePreview> {
  final TextEditingController _captionController = TextEditingController();
  String _caption = '';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _handleSend() {
    widget.onSend(widget.imageFile, _caption);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Image viewer with pinch-to-zoom
            Positioned.fill(
              child: PhotoView(
                imageProvider: FileImage(widget.imageFile),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: const PhotoViewHeroAttributes(
                  tag: 'image_preview',
                ),
              ),
            ),

            // Top bar with close button and tools
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    // Close button (X)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    const Spacer(),

                    // HD Quality button
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('HD quality enabled'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Color(0xFF128C7E),
                            ),
                          );
                        },
                        icon: const Text(
                          'HD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Crop tool
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Crop feature coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.crop_rotate_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Sticker tool
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sticker feature coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.layers_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Text tool (Aa)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Text feature coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Text(
                          'Aa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Draw/Pen tool
                    Container(
                      margin: const EdgeInsets.only(right: 8, left: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Drawing feature coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar with recipient name, caption, and send button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recipient name (if provided)
                    if (widget.recipientName != null)
                      Container(
                        padding: const EdgeInsets.only(
                          left: 20,
                          top: 16,
                          bottom: 8,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.recipientName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Caption input and send button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Caption input (left side - gallery icon)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () {
                                // TODO: Open gallery for more images
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Gallery feature coming soon!',
                                    ),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Caption text field
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _captionController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add a caption...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.access_time_rounded,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                ),
                                maxLines: 4,
                                minLines: 1,
                                onChanged: (value) {
                                  setState(() {
                                    _caption = value;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Send button
                          GestureDetector(
                            onTap: _handleSend,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
