import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;

  /// Check and request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      debugPrint('🎤 AudioService: Microphone permission status: $status');
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

      // Check if already recording
      if (_isRecording) {
        debugPrint('🎤 AudioService: Already recording, ignoring request');
        return false;
      }

      // Check permission first
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('🎤 AudioService: Microphone permission denied');
        return false;
      }

      // Double-check with recorder's permission check
      final canRecord = await _recorder.hasPermission();
      if (!canRecord) {
        debugPrint('🎤 AudioService: Recorder permission check failed');
        return false;
      }

      // Stop any previous recording
      final isCurrentlyRecording = await _recorder.isRecording();
      if (isCurrentlyRecording) {
        debugPrint('🎤 AudioService: Stopping previous recording session');
        await _recorder.stop();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/audio_$timestamp.m4a';

      // Configure recording settings for v6.1.2
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC - widely supported
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true, // Enable automatic gain control
        echoCancel: true, // Enable echo cancellation
        noiseSuppress: true, // Enable noise suppression
      );

      // Start recording with path
      await _recorder.start(config, path: _currentRecordingPath!);

      // Verify recording started
      final isNowRecording = await _recorder.isRecording();
      if (!isNowRecording) {
        debugPrint('🎤 AudioService: Recording failed to start');
        return false;
      }

      _isRecording = true;
      debugPrint(
        '🎤 AudioService: Recording started successfully at $_currentRecordingPath',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('🎤 AudioService: Error starting recording: $e');
      debugPrint('🎤 AudioService: Stack trace: $stackTrace');
      _isRecording = false;
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

      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint(
            '🎤 AudioService: Recording stopped, file saved at $path ($fileSize bytes)',
          );
          return file;
        } else {
          debugPrint('🎤 AudioService: Recording file does not exist at $path');
          return null;
        }
      } else {
        debugPrint('🎤 AudioService: Recording failed, no path returned');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('🎤 AudioService: Error stopping recording: $e');
      debugPrint('🎤 AudioService: Stack trace: $stackTrace');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel current recording
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.cancel();
        _isRecording = false;

        // Delete the recording file if it exists
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('🎤 AudioService: Recording file deleted');
          }
        }

        debugPrint('🎤 AudioService: Recording cancelled');
      }
    } catch (e) {
      debugPrint('🎤 AudioService: Error cancelling recording: $e');
    }
  }

  /// Pause recording (v6+ feature)
  static Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        await _recorder.pause();
        debugPrint('🎤 AudioService: Recording paused');
      }
    } catch (e) {
      debugPrint('🎤 AudioService: Error pausing recording: $e');
    }
  }

  /// Resume recording (v6+ feature)
  static Future<void> resumeRecording() async {
    try {
      final isPaused = await _recorder.isPaused();
      if (isPaused) {
        await _recorder.resume();
        debugPrint('🎤 AudioService: Recording resumed');
      }
    } catch (e) {
      debugPrint('🎤 AudioService: Error resuming recording: $e');
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

  /// Get current recording amplitude (v6+ feature)
  static Future<double?> getAmplitude() async {
    try {
      if (_isRecording) {
        final amplitude = await _recorder.getAmplitude();
        return amplitude.current;
      }
      return null;
    } catch (e) {
      debugPrint('🎤 AudioService: Error getting amplitude: $e');
      return null;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _recorder.dispose();
      await _player.dispose();
      debugPrint('🎤🔊 AudioService: Resources disposed');
    } catch (e) {
      debugPrint('🎤🔊 AudioService: Error disposing resources: $e');
    }
  }

  /// Get audio duration from file
  static Future<Duration?> getAudioDuration(String audioPath) async {
    try {
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

  /// Clean up and close the recorder
  static Future<void> cleanup() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      await _recorder.dispose();
      debugPrint('🎤 AudioService: Recorder cleaned up');
    } catch (e) {
      debugPrint('🎤 AudioService: Error cleaning up recorder: $e');
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
