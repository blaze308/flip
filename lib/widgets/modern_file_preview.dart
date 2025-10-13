import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class ModernFilePreview extends StatefulWidget {
  final File file;
  final String recipientName;
  final Function(String? caption) onSend;
  final VoidCallback onCancel;

  const ModernFilePreview({
    super.key,
    required this.file,
    required this.recipientName,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<ModernFilePreview> createState() => _ModernFilePreviewState();
}

class _ModernFilePreviewState extends State<ModernFilePreview> {
  final TextEditingController _captionController = TextEditingController();
  String _fileSize = '';
  String _fileName = '';

  @override
  void initState() {
    super.initState();
    _loadFileInfo();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadFileInfo() async {
    final fileSize = await widget.file.length();
    final fileName = path.basename(widget.file.path);

    setState(() {
      _fileSize = _formatFileSize(fileSize);
      _fileName = fileName;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: Column(
        children: [
          // Top Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Close button
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: widget.onCancel,
                    padding: const EdgeInsets.all(8),
                  ),
                  const Spacer(),
                  // File name in center
                  Expanded(
                    flex: 3,
                    child: Text(
                      _fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Document Preview Area (White background like WhatsApp)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Title
                      Center(
                        child: Text(
                          _fileName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // File size
                      Center(
                        child: Text(
                          _fileSize,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Document icon/preview placeholder
                      Center(
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Placeholder text (mimicking document content)
                      Text(
                        'Document Preview',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'File: $_fileName\nSize: $_fileSize',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Bar with caption
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Color(0xFF0B141A)),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Recipient name
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),

                  // Caption input
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2C34),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Send Button
                  GestureDetector(
                    onTap: () {
                      final caption = _captionController.text.trim();
                      widget.onSend(caption.isEmpty ? null : caption);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
