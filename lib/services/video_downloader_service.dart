import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class MediaDownloaderService {
  static final Dio _dio = Dio();

  /// Download image with progress callback
  static Future<DownloadResult> downloadImage({
    required String imageUrl,
    required String fileName,
    required Function(double progress) onProgress,
  }) async {
    try {
      print('📥 MediaDownloader: Starting image download for $fileName');

      // Check if Gal has permission
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          return DownloadResult(
            success: false,
            message: 'Storage permission denied',
          );
        }
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Download the image with progress tracking
      await _dio.download(
        imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print(
              '📥 Download progress: ${(progress * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      print('📥 MediaDownloader: Download complete, saving to gallery...');

      // Save to gallery using Gal package
      await Gal.putImage(filePath);

      print('✅ MediaDownloader: Image saved to gallery successfully');

      // Clean up temporary file
      try {
        await File(filePath).delete();
      } catch (e) {
        print('⚠️ MediaDownloader: Failed to delete temp file: $e');
      }

      return DownloadResult(
        success: true,
        message: 'Image saved to gallery',
        filePath: filePath,
      );
    } on DioException catch (e) {
      print('❌ MediaDownloader: Dio error: ${e.message}');
      return DownloadResult(
        success: false,
        message: 'Download failed: ${e.message}',
      );
    } catch (e) {
      print('❌ MediaDownloader: Error downloading image: $e');
      return DownloadResult(
        success: false,
        message: 'Download failed: ${e.toString()}',
      );
    }
  }
}

class VideoDownloaderService {
  static final Dio _dio = Dio();

  /// Download video with progress callback (TikTok-style)
  static Future<DownloadResult> downloadVideo({
    required String videoUrl,
    required String fileName,
    required Function(double progress) onProgress,
  }) async {
    try {
      print('📥 MediaDownloader: Starting video download for $fileName');

      // Check if Gal has permission (it handles permission requests automatically)
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        // Request permission through Gal
        final granted = await Gal.requestAccess();
        if (!granted) {
          return DownloadResult(
            success: false,
            message: 'Storage permission denied',
          );
        }
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Download the video with progress tracking
      await _dio.download(
        videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print(
              '📥 Download progress: ${(progress * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      print('📥 MediaDownloader: Download complete, saving to gallery...');

      // Save to gallery using Gal package
      await Gal.putVideo(filePath);

      print('✅ MediaDownloader: Video saved to gallery successfully');

      // Clean up temporary file
      try {
        await File(filePath).delete();
      } catch (e) {
        print('⚠️ VideoDownloader: Failed to delete temp file: $e');
      }

      return DownloadResult(
        success: true,
        message: 'Video saved to gallery',
        filePath: filePath,
      );
    } on DioException catch (e) {
      print('❌ VideoDownloader: Dio error: ${e.message}');
      return DownloadResult(
        success: false,
        message: 'Download failed: ${e.message}',
      );
    } catch (e) {
      print('❌ VideoDownloader: Error downloading video: $e');
      return DownloadResult(
        success: false,
        message: 'Download failed: ${e.toString()}',
      );
    }
  }

  /// Cancel ongoing download
  static void cancelDownload(CancelToken cancelToken) {
    cancelToken.cancel('Download cancelled by user');
  }

  /// Get download progress as percentage string
  static String getProgressPercentage(double progress) {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  /// Get download progress as MB string
  static String getProgressMB(int received, int total) {
    final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
    final totalMB = (total / 1024 / 1024).toStringAsFixed(1);
    return '$receivedMB MB / $totalMB MB';
  }
}

/// Download result model
class DownloadResult {
  final bool success;
  final String message;
  final String? filePath;

  DownloadResult({required this.success, required this.message, this.filePath});
}
