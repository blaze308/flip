import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;

  /// Check and request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('🎤 AudioService: Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio
  static Future<bool> startRecording() async {
    try {
      debugPrint('🎤 AudioService: Starting audio recording...');

      // Check permission
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('🎤 AudioService: Microphone permission denied');
        return false;
      }

      // Check if already recording
      if (_isRecording) {
        debugPrint('🎤 AudioService: Already recording');
        return false;
      }

      // Initialize recorder if needed
      if (!_recorder.isRecording) {
        await _recorder.openRecorder();
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Try different codecs in order of preference
      final codecs = [
        {'codec': Codec.pcm16WAV, 'ext': 'wav'},
        {'codec': Codec.aacMP4, 'ext': 'm4a'},
        {'codec': Codec.defaultCodec, 'ext': 'm4a'},
      ];

      Exception? lastError;
      for (final codecInfo in codecs) {
        try {
          _currentRecordingPath =
              '${tempDir.path}/audio_$timestamp.${codecInfo['ext']}';

          await _recorder.startRecorder(
            toFile: _currentRecordingPath!,
            codec: codecInfo['codec'] as Codec,
            bitRate: 64000,
            sampleRate: 22050,
          );

          debugPrint(
            '🎤 AudioService: Recording started with ${codecInfo['codec']} at $_currentRecordingPath',
          );
          break; // Success, exit loop
        } catch (codecError) {
          lastError = codecError as Exception;
          debugPrint(
            '🎤 AudioService: ${codecInfo['codec']} failed: $codecError',
          );
          continue;
        }
      }

      // If we get here and not recording, all codecs failed
      if (!_recorder.isRecording) {
        throw lastError ?? Exception('All audio codecs failed');
      }

      _isRecording = true;
      debugPrint(
        '🎤 AudioService: Recording started at $_currentRecordingPath',
      );
      return true;
    } catch (e) {
      debugPrint('🎤 AudioService: Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the audio file
  static Future<File?> stopRecording() async {
    try {
      debugPrint('🎤 AudioService: Stopping audio recording...');

      if (!_isRecording) {
        debugPrint('🎤 AudioService: Not currently recording');
        return null;
      }

      final path = await _recorder.stopRecorder();
      _isRecording = false;

      if (path != null && await File(path).exists()) {
        debugPrint('🎤 AudioService: Recording stopped, file saved at $path');
        return File(path);
      } else {
        debugPrint('🎤 AudioService: Recording failed, no file created');
        return null;
      }
    } catch (e) {
      debugPrint('🎤 AudioService: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel current recording
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        _isRecording = false;

        // Delete the recording file
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }

        debugPrint('🎤 AudioService: Recording cancelled');
      }
    } catch (e) {
      debugPrint('🎤 AudioService: Error cancelling recording: $e');
    }
  }

  /// Play audio from URL
  static Future<bool> playAudio(String audioUrl) async {
    try {
      debugPrint('🔊 AudioService: Playing audio from $audioUrl');

      if (_isPlaying) {
        await stopAudio();
      }

      await _player.play(UrlSource(audioUrl));
      _isPlaying = true;
      return true;
    } catch (e) {
      debugPrint('🔊 AudioService: Error playing audio: $e');
      return false;
    }
  }

  /// Play audio from local file
  static Future<bool> playAudioFile(File audioFile) async {
    try {
      debugPrint('🔊 AudioService: Playing audio file ${audioFile.path}');

      if (_isPlaying) {
        await stopAudio();
      }

      await _player.play(DeviceFileSource(audioFile.path));
      _isPlaying = true;
      return true;
    } catch (e) {
      debugPrint('🔊 AudioService: Error playing audio file: $e');
      return false;
    }
  }

  /// Stop audio playback
  static Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('🔊 AudioService: Audio playback stopped');
    } catch (e) {
      debugPrint('🔊 AudioService: Error stopping audio: $e');
    }
  }

  /// Pause audio playback
  static Future<void> pauseAudio() async {
    try {
      await _player.pause();
      debugPrint('🔊 AudioService: Audio playback paused');
    } catch (e) {
      debugPrint('🔊 AudioService: Error pausing audio: $e');
    }
  }

  /// Resume audio playback
  static Future<void> resumeAudio() async {
    try {
      await _player.resume();
      debugPrint('🔊 AudioService: Audio playback resumed');
    } catch (e) {
      debugPrint('🔊 AudioService: Error resuming audio: $e');
    }
  }

  /// Get current recording status
  static bool get isRecording => _isRecording;

  /// Get current playback status
  static bool get isPlaying => _isPlaying;

  /// Get audio player instance for advanced controls
  static AudioPlayer get player => _player;

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _recorder.closeRecorder();
      await _player.dispose();
      debugPrint('🎤🔊 AudioService: Resources disposed');
    } catch (e) {
      debugPrint('🎤🔊 AudioService: Error disposing resources: $e');
    }
  }

  /// Get audio duration from file
  static Future<Duration?> getAudioDuration(String audioPath) async {
    try {
      // This is a simplified approach - in a real app you might want to use
      // a more robust method to get audio duration
      final player = AudioPlayer();
      await player.setSource(UrlSource(audioPath));
      final duration = await player.getDuration();
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('🔊 AudioService: Error getting audio duration: $e');
      return null;
    }
  }
}

/// Audio recording result
class AudioRecordingResult {
  final bool success;
  final File? audioFile;
  final String message;
  final Duration? duration;

  const AudioRecordingResult({
    required this.success,
    this.audioFile,
    required this.message,
    this.duration,
  });
}
