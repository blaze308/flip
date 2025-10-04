import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'da0axqsaj';
  static const String baseUrl = 'https://api.cloudinary.com/v1_1/$cloudName';

  /// Get all Lottie files from the "lotties" folder
  static Future<List<CloudinaryAsset>> getLottieFiles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/resources/raw?prefix=lotties/&max_results=100'),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('YOUR_API_KEY:YOUR_API_SECRET'))}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resources = data['resources'] as List;

        return resources
            .map(
              (resource) => CloudinaryAsset(
                publicId: resource['public_id'],
                url: resource['secure_url'],
                fileName: resource['public_id'].split('/').last,
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Lottie files: $e');
      return [];
    }
  }

  /// Get all SVGA files and their corresponding images from the "svga" folder
  static Future<List<SvgaAsset>> getSvgaFiles() async {
    try {
      // Get SVGA files
      final svgaResponse = await http.get(
        Uri.parse('$baseUrl/resources/raw?prefix=svga/&max_results=100'),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('YOUR_API_KEY:YOUR_API_SECRET'))}',
        },
      );

      // Get image files from the same folder
      final imageResponse = await http.get(
        Uri.parse('$baseUrl/resources/image?prefix=svga/&max_results=100'),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('YOUR_API_KEY:YOUR_API_SECRET'))}',
        },
      );

      if (svgaResponse.statusCode == 200 && imageResponse.statusCode == 200) {
        final svgaData = json.decode(svgaResponse.body);
        final imageData = json.decode(imageResponse.body);

        final svgaResources = svgaData['resources'] as List;
        final imageResources = imageData['resources'] as List;

        final svgaAssets = <SvgaAsset>[];

        for (final svgaResource in svgaResources) {
          final publicId = svgaResource['public_id'] as String;
          final baseName = publicId.split('/').last.split('.').first;

          // Find corresponding image
          final imageResource = imageResources.firstWhere(
            (img) => (img['public_id'] as String).contains(baseName),
            orElse: () => null,
          );

          svgaAssets.add(
            SvgaAsset(
              publicId: publicId,
              svgaUrl: svgaResource['secure_url'],
              imageUrl: imageResource?['secure_url'],
              fileName: baseName,
            ),
          );
        }

        return svgaAssets;
      }
      return [];
    } catch (e) {
      print('Error fetching SVGA files: $e');
      return [];
    }
  }

  /// Get actual Lottie files from assets or return empty if none exist
  static List<CloudinaryAsset> getMockLottieFiles() {
    // Return empty list since folders are empty
    // TODO: Add actual Lottie files to Cloudinary lotties folder
    return [];
  }

  /// Get actual SVGA files from assets or return empty if none exist
  static List<SvgaAsset> getMockSvgaFiles() {
    // Return empty list since folders are empty
    // TODO: Add actual SVGA files to Cloudinary svga folder
    return [];
  }
}

class CloudinaryAsset {
  final String publicId;
  final String url;
  final String fileName;

  CloudinaryAsset({
    required this.publicId,
    required this.url,
    required this.fileName,
  });
}

class SvgaAsset {
  final String publicId;
  final String svgaUrl;
  final String? imageUrl;
  final String fileName;

  SvgaAsset({
    required this.publicId,
    required this.svgaUrl,
    this.imageUrl,
    required this.fileName,
  });
}
