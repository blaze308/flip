import 'dart:io';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class VideoUtils {
  /// Trim video to specified duration (default 30 seconds for stories)
  /// Returns the path to the trimmed video file
  static Future<File?> trimVideo(
    String inputPath, {
    int maxDurationSeconds = 30,
  }) async {
    try {
      print('🎬 VideoUtils: Trimming video to $maxDurationSeconds seconds');
      print('🎬 VideoUtils: Input path: $inputPath');

      // Get video info first
      final info = await VideoCompress.getMediaInfo(inputPath);
      final originalDuration = info.duration;

      if (originalDuration == null) {
        print('🎬 VideoUtils: Could not get video duration');
        return null;
      }

      print('🎬 VideoUtils: Original duration: ${originalDuration}ms');

      // If video is already 30 seconds or less, no need to trim
      if (originalDuration <= maxDurationSeconds * 1000) {
        print('🎬 VideoUtils: Video already under $maxDurationSeconds seconds');
        return File(inputPath);
      }

      // Trim the video
      final result = await VideoCompress.compressVideo(
        inputPath,
        quality: VideoQuality.HighestQuality,
        deleteOrigin: false,
        startTime: 0,
        duration: maxDurationSeconds, // Duration in seconds
        includeAudio: true,
      );

      if (result != null && result.file != null) {
        print('🎬 VideoUtils: Video trimmed successfully');
        print('🎬 VideoUtils: Output path: ${result.path}');
        print('🎬 VideoUtils: File size: ${result.filesize} bytes');
        return result.file;
      } else {
        print('🎬 VideoUtils: Video compression/trim returned null');
        return null;
      }
    } catch (e) {
      print('🎬 VideoUtils: Error trimming video: $e');
      return null;
    }
  }

  /// Get video duration in seconds using video_player
  static Future<int?> getVideoDuration(String videoPath) async {
    VideoPlayerController? controller;
    try {
      print('🎬 VideoUtils: Getting video duration for: $videoPath');

      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      final duration = controller.value.duration.inSeconds;
      print('🎬 VideoUtils: Video duration: $duration seconds');

      return duration;
    } catch (e) {
      print('🎬 VideoUtils: Error getting video duration: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Clean up temporary trimmed video files
  static Future<void> cleanupTempVideos() async {
    try {
      // Video compress handles cleanup automatically
      await VideoCompress.deleteAllCache();
      print('🎬 VideoUtils: Cleaned up all video cache');
    } catch (e) {
      print('🎬 VideoUtils: Error cleaning up temp videos: $e');
    }
  }
}
