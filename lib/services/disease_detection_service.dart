import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'disease_detection_interface.dart';
import 'analytics_service.dart';

// TensorFlow Lite types
const int float32 = 1;

// TensorBuffer class
class TensorBuffer {
  final List<double> _data;

  TensorBuffer(List<double> data) : _data = data;

  static TensorBuffer createFixedSize(List<int> shape, int type) {
    final size = shape.reduce((a, b) => a * b);
    return TensorBuffer(List<double>.filled(size, 0.0));
  }

  void loadFloatList(List<double> data) {
    if (data.length != _data.length) {
      throw Exception('Data length mismatch');
    }
    _data.setAll(0, data);
  }

  List<double> getDoubleList() => _data;
}

class DiseaseDetectionService implements DiseaseDetectionInterface {
  static tflite.Interpreter? _interpreter;
  static List<String>? _labels;

  @override
  Future<Map<String, dynamic>> detectDisease({
    File? imageFile,
    String? imageUrl,
  }) async {
    debugPrint('\n=== Starting Disease Detection Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Input: ${imageFile?.path ?? imageUrl ?? 'No input provided'}');

    try {
      // Load model if not already loaded
      debugPrint('Loading TFLite model...');
      if (_interpreter == null) {
        await _loadModel();
        await _loadLabels();
      }
      debugPrint('Model loaded successfully');

      // Process the image
      debugPrint('Running inference on image...');
      
      // Load and preprocess the image
      final image = await imageFile?.readAsBytes();
      if (image == null) {
        throw Exception('Image not found');
      }

      // Convert image to tensor input
      final processedImage = await preprocessImage(image);
      
      // Prepare input tensor
      final inputTensor = _interpreter!.getInputTensors().first;
      final outputTensor = _interpreter!.getOutputTensors().first;
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;
      
      debugPrint('Input shape: $inputShape');
      debugPrint('Output shape: $outputShape');

      // Create input and output buffers
      final inputBuffer = Float32List(inputShape.reduce((a, b) => a * b));
      final outputBuffer = Float32List(outputShape.reduce((a, b) => a * b));

      // Copy preprocessed image data to input buffer
      inputBuffer.setAll(0, processedImage);

      // Run inference
      _interpreter!.run(inputBuffer.buffer, outputBuffer.buffer);
      
      // Process YOLO output
      final results = processYoloOutput(outputBuffer, outputShape);
      
      if (results.isEmpty) {
        throw Exception('No disease detected in the image');
      }

      // Get the detection with highest confidence
      final bestDetection = results.reduce((a, b) => a['confidence'] > b['confidence'] ? a : b);
      
      debugPrint('Inference results:');
      debugPrint('- Label: ${bestDetection['disease']}');
      debugPrint('- Confidence: ${(bestDetection['confidence'] * 100).toStringAsFixed(1)}%');
      debugPrint('- Bbox: ${bestDetection['bbox']}');

      // Submit to analytics (fire and forget)
      _submitToAnalytics(bestDetection, imageFile);

      debugPrint('=== Disease Detection Service Completed ===\n');
      return bestDetection;
    } catch (e) {
      debugPrint('Error in disease detection service: $e');
      debugPrint('=== Disease Detection Service Failed ===\n');
      throw Exception('Error detecting disease: $e');
    }
  }

  static void _submitToAnalytics(Map<String, dynamic> detection, File? imageFile) {
    // Submit analytics data in background without blocking the UI
    Future(() async {
      try {
        // You could upload the image to get a URL, or use a placeholder
        String imageUrl = 'placeholder_url';
        
        await AnalyticsService.submitDiseaseReport(
          disease: detection['disease'],
          confidence: detection['confidence'],
          imageUrl: imageUrl,
          // Add location data if available
        );
      } catch (e) {
        debugPrint('Failed to submit analytics: $e');
      }
    });
  }

  static List<Map<String, dynamic>> processYoloOutput(Float32List output, List<int> outputShape) {
    final results = <Map<String, dynamic>>[];
    final numClasses = outputShape[1] - 5;  // YOLO output format: [x, y, w, h, conf, class_scores...]
    final numDetections = outputShape[2];
    
    debugPrint('\n=== Processing YOLO Output ===');
    debugPrint('Number of classes: $numClasses');
    debugPrint('Number of detections: $numDetections');
    debugPrint('Confidence threshold: ${DiseaseDetectionInterface.confidenceThreshold}');

    var totalAboveThreshold = 0;
    var totalWithClassScore = 0;

    for (var i = 0; i < numDetections; i++) {
      final baseIdx = i * outputShape[1];
      final confidence = output[baseIdx + 4];

      if (confidence > DiseaseDetectionInterface.confidenceThreshold) {
        totalAboveThreshold++;
        // Get class scores
        var maxClassScore = 0.0;
        var maxClassIndex = 0;
        for (var c = 0; c < numClasses; c++) {
          final score = output[baseIdx + 5 + c];
          if (score > maxClassScore) {
            maxClassScore = score;
            maxClassIndex = c;
          }
        }

        final finalConfidence = confidence * maxClassScore;
        if (finalConfidence > DiseaseDetectionInterface.confidenceThreshold) {
          totalWithClassScore++;
          // Convert bbox from YOLO format
          final x = output[baseIdx];
          final y = output[baseIdx + 1];
          final w = output[baseIdx + 2];
          final h = output[baseIdx + 3];

          debugPrint('\nDetection $i:');
          debugPrint('- Base confidence: ${(confidence * 100).toStringAsFixed(1)}%');
          debugPrint('- Class: ${_labels?[maxClassIndex] ?? 'Unknown'}');
          debugPrint('- Class score: ${(maxClassScore * 100).toStringAsFixed(1)}%');
          debugPrint('- Final confidence: ${(finalConfidence * 100).toStringAsFixed(1)}%');
          debugPrint('- Bounding box: [$x, $y, $w, $h]');

          results.add({
            'disease': _labels?[maxClassIndex] ?? 'Unknown',
            'confidence': finalConfidence,
            'bbox': [x, y, w, h],
          });
        }
      }
    }

    debugPrint('\nDetection Summary:');
    debugPrint('- Total detections processed: $numDetections');
    debugPrint('- Detections above confidence threshold: $totalAboveThreshold');
    debugPrint('- Final detections with class scores: $totalWithClassScore');
    debugPrint('=== YOLO Processing Complete ===\n');

    return results;
  }

  static Future<void> _loadModel() async {
    try {
      final interpreterOptions = tflite.InterpreterOptions()..threads = 4;
      
      // Load model from assets
      final modelFile = await _getModel();
      _interpreter = tflite.Interpreter.fromFile(modelFile, options: interpreterOptions);
      
      debugPrint('Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading model: $e');
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  static Future<File> _getModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDir.path}/model.tflite';
    final modelFile = File(modelPath);

    if (!await modelFile.exists()) {
      final modelBytes = await rootBundle.load('assets/model.tflite');
      await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
    }
    return modelFile;
  }

  static Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim().replaceAll('-', ' '))  // Replace hyphens with spaces
          .toList();
      debugPrint('Labels loaded successfully: ${_labels?.length} labels');
      debugPrint('Normalized labels: ${_labels?.join(", ")}');
    } catch (e) {
      debugPrint('Error loading labels: $e');
      throw Exception('Failed to load labels: $e');
    }
  }

  static Future<List<double>> preprocessImage(List<int> imageBytes) async {
    final Uint8List uint8List = Uint8List.fromList(imageBytes);
    final img.Image? originalImage = img.decodeImage(uint8List);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // Calculate aspect-preserving resize dimensions
    double scale = DiseaseDetectionInterface.inputSize / math.max(originalImage.width, originalImage.height);
    int newWidth = (originalImage.width * scale).round();
    int newHeight = (originalImage.height * scale).round();

    // Resize image preserving aspect ratio
    final resizedImage = img.copyResize(
      originalImage,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // Create a square image with padding
    final paddedImage = img.Image(width: DiseaseDetectionInterface.inputSize, height: DiseaseDetectionInterface.inputSize);
    // Fill with black (padding)
    final black = img.ColorRgb8(0, 0, 0);
    for (int y = 0; y < DiseaseDetectionInterface.inputSize; y++) {
      for (int x = 0; x < DiseaseDetectionInterface.inputSize; x++) {
        paddedImage.setPixel(x, y, black);
      }
    }

    // Calculate padding
    final xOffset = ((DiseaseDetectionInterface.inputSize - newWidth) / 2).round();
    final yOffset = ((DiseaseDetectionInterface.inputSize - newHeight) / 2).round();

    // Copy resized image to center of padded image
    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        paddedImage.setPixel(x + xOffset, y + yOffset, resizedImage.getPixel(x, y));
      }
    }

    // Convert to float32 and normalize to [0, 1]
    final Float32List normalizedPixels = Float32List(DiseaseDetectionInterface.inputSize * DiseaseDetectionInterface.inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < DiseaseDetectionInterface.inputSize; y++) {
      for (int x = 0; x < DiseaseDetectionInterface.inputSize; x++) {
        final pixel = paddedImage.getPixel(x, y);
        // Extract RGB values and normalize to [0, 1]
        normalizedPixels[pixelIndex++] = pixel.r / 255.0; // R
        normalizedPixels[pixelIndex++] = pixel.g / 255.0; // G
        normalizedPixels[pixelIndex++] = pixel.b / 255.0; // B
      }
    }

    return normalizedPixels.toList();
  }

  @override
  Future<void> dispose() async {
    debugPrint('\n=== Disposing Disease Detection Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
    _labels = null;
    debugPrint('Model disposed successfully');
    debugPrint('=== Disease Detection Service Disposed ===\n');
  }
}