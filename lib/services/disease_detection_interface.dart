import 'dart:io';

abstract class DiseaseDetectionInterface {
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.25;
  static const double iouThreshold = 0.45;

  Future<Map<String, dynamic>> detectDisease({
    File? imageFile,
    String? imageUrl,
  });

  Future<void> dispose();

  static Future<void> loadLabels() async {}
} 