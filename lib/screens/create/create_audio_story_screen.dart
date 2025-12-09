import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/story_service.dart';
import '../../services/audio_service.dart';
import '../../models/story_model.dart';
import '../../widgets/custom_toaster.dart';
import '../../providers/app_providers.dart';

class CreateAudioStoryScreen extends ConsumerStatefulWidget {
  const CreateAudioStoryScreen({super.key});

  @override
  ConsumerState<CreateAudioStoryScreen> createState() =>
      _CreateAudioStoryScreenState();
}

class _CreateAudioStoryScreenState
    extends ConsumerState<CreateAudioStoryScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedAudio;
  bool _isLoading = false;
  String? _audioFileName;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Privacy settings
  final StoryPrivacyType _privacy = StoryPrivacyType.public;
  final bool _allowReplies = true;
  final bool _allowReactions = true;
  final bool _allowScreenshot = true;

  @override
  void initState() {
    super.initState();
    // Show dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAudioSourceDialog();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _showAudioSourceDialog() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Select Audio Source',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.mic,
                        title: 'Record',
                        subtitle: 'Record new audio',
                        onTap: () => Navigator.of(context).pop('record'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.audio_file,
                        title: 'Upload',
                        subtitle: 'Choose from files',
                        onTap: () => Navigator.of(context).pop('upload'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );

    if (result == 'upload') {
      await _pickAudioFile();
    } else if (result == null || result == 'cancel') {
      // User dismissed modal without selecting - go back
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    // If result == 'record', just close modal and show the record button in UI
  }

  Future<void> _startRecording() async {
    // Prevent multiple simultaneous recording attempts
    if (_isRecording) {
      print('🎤 Already recording, ignoring start request');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Small delay to ensure UI is stable
    await Future.delayed(const Duration(milliseconds: 300));

    final success = await AudioService.startRecording();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start timer to update duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });

      if (mounted) {
        context.showSuccessToaster('Recording started - speak now!');
      }
    } else {
      if (mounted) {
        context.showErrorToaster(
          'Failed to start recording. Please check microphone permissions.',
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    // Check minimum recording duration
    if (_recordingDuration.inSeconds < 1) {
      context.showErrorToaster(
        'Recording too short. Minimum 1 second required.',
      );
      setState(() {
        _isRecording = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final audioFile = await AudioService.stopRecording();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLoading = false;
      });

      if (audioFile != null) {
        // Check file size
        final fileSize = await audioFile.length();
        print('🎵 Audio file size: $fileSize bytes');

        if (fileSize < 1000) {
          // Less than 1KB is suspicious
          context.showErrorToaster(
            'Recording failed. Audio file is too small. Please try again.',
          );
          Navigator.of(context).pop();
          return;
        }

        setState(() {
          _selectedAudio = audioFile;
          _audioFileName =
              'Recorded Audio (${_formatDuration(_recordingDuration)})';
        });
        context.showSuccessToaster('Recording saved');
      } else {
        context.showErrorToaster('Failed to save recording');
        Navigator.of(context).pop();
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedAudio = File(result.files.single.path!);
          _audioFileName = result.files.single.name;
        });
      } else {
        // User cancelled file selection
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster('Failed to pick audio file: $e');
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _createStory() async {
    if (_selectedAudio == null) {
      context.showErrorToaster('Please select an audio file');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StoryService.createMediaStory(
        mediaFile: _selectedAudio!,
        mediaType: StoryMediaType.audio,
        caption: _captionController.text.trim(),
        privacy: _privacy,
        allowReplies: _allowReplies,
        allowReactions: _allowReactions,
        allowScreenshot: _allowScreenshot,
      );

      if (result.success && mounted) {
        // Refresh stories to show the new one
        ref.read(storiesProvider.notifier).refresh();

        context.showSuccessToaster('Audio story created successfully!');
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Audio Story',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed:
                _selectedAudio != null && !_isLoading ? _createStory : null,
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
                    : const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
      body:
          _isRecording
              ? _buildRecordingView()
              : (_selectedAudio == null
                  ? _buildEmptyState()
                  : _buildAudioPreview()),
    );
  }

  Widget _buildRecordingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated recording indicator
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, double value, child) {
              return Container(
                width: 120 + (value * 20),
                height: 120 + (value * 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.3 - (value * 0.3)),
                ),
              );
            },
            onEnd: () {
              if (mounted && _isRecording) {
                setState(() {}); // Trigger rebuild to restart animation
              }
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.mic, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Recording...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 48,
              fontWeight: FontWeight.w300,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Recording'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big record button
          GestureDetector(
            onTap: _isLoading ? null : _startRecording,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    _isLoading
                        ? null
                        : const LinearGradient(
                          colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                color: _isLoading ? Colors.grey[700] : null,
                boxShadow:
                    _isLoading
                        ? null
                        : [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
              ),
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : const Icon(Icons.mic, size: 70, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _isLoading ? 'Starting...' : 'Tap to Record',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hold and speak clearly',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 48),
          // Secondary option to upload
          TextButton.icon(
            onPressed: _pickAudioFile,
            icon: const Icon(Icons.audio_file, color: Color(0xFF4ECDC4)),
            label: const Text(
              'Or upload audio file',
              style: TextStyle(color: Color(0xFF4ECDC4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Column(
      children: [
        // Audio preview
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFF39C12), Color(0xFFE67E22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.audiotrack,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Audio Story',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _audioFileName ?? 'Audio file',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Audio waveform placeholder
                      Container(
                        width: 200,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(20, (index) {
                            return Container(
                              width: 3,
                              height: (index % 4 + 1) * 8.0,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(204),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // Change audio button
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _showAudioSourceDialog,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(76),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Caption input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe your audio story...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[300], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Supported formats: MP3, WAV, M4A, AAC',
                        style: TextStyle(color: Colors.blue[300], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4ECDC4), size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
