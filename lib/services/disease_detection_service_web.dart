import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'disease_detection_interface.dart';

class DiseaseDetectionService implements DiseaseDetectionInterface {
  static const String apiUrl = 'https://your-api-endpoint.com/predict'; // Replace with your actual API endpoint
  static bool _isInitialized = false;
  static List<String>? _labels;

  @override
  Future<Map<String, dynamic>> detectDisease({
    File? imageFile,
    String? imageUrl,
  }) async {
    try {
      if (!_isInitialized) {
        await _loadLabels();
        _isInitialized = true;
      }

      // Prepare the image data
      String? base64Image;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // Make API request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image ?? imageUrl,
          'isUrl': imageUrl != null,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process image: ${response.body}');
      }

      final result = jsonDecode(response.body);
      return {
        'disease': result['disease'],
        'confidence': result['confidence'],
        'bbox': result['bbox'] ?? [0.0, 0.0, 1.0, 1.0],
      };
    } catch (e) {
      debugPrint('Error in web disease detection: $e');
      throw Exception('Failed to detect disease: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim().replaceAll('-', ' '))
          .toList();
      debugPrint('Labels loaded successfully: ${_labels?.length} labels');
    } catch (e) {
      debugPrint('Error loading labels: $e');
      throw Exception('Failed to load labels: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _labels = null;
  }
} 