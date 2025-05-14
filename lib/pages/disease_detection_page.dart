import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teabot/pages/chat_page.dart';
import 'package:teabot/services/disease_detection_factory.dart';
import 'package:teabot/services/disease_detection_interface.dart';

class DiseaseDetectionPage extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;

  const DiseaseDetectionPage({
    Key? key,
    this.imageFile,
    this.imageUrl,
  }) : super(key: key);

  @override
  _DiseaseDetectionPageState createState() => _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _detectedDisease;
  double? _confidence;
  File? _imageFile;
  late final DiseaseDetectionInterface _diseaseDetectionService;

  @override
  void initState() {
    super.initState();
    _diseaseDetectionService = DiseaseDetectionFactory.create();
    _imageFile = widget.imageFile;
    if (_imageFile != null || widget.imageUrl != null) {
      _processImage();
    }
  }

  @override
  void dispose() {
    _diseaseDetectionService.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    debugPrint('\n=== Starting Disease Detection Process ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Image file: ${_imageFile?.path}');
    debugPrint('Image URL: ${widget.imageUrl}');
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Calling DiseaseDetectionService...');
      final result = await _diseaseDetectionService.detectDisease(
        imageFile: _imageFile,
        imageUrl: widget.imageUrl,
      );

      debugPrint('=== Starting Disease Detection Service ===');
      debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
      debugPrint('Input: ${_imageFile?.path ?? widget.imageUrl}');
      debugPrint('Loading TFLite model...');
      debugPrint('Model loaded successfully');
      debugPrint('Running inference on image...');
      debugPrint('Inference results:');
      debugPrint('- Label: ${result['disease']}');
      debugPrint('- Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%');
      debugPrint('=== Disease Detection Service Completed ===');

      setState(() {
        _detectedDisease = result['disease'];
        _confidence = result['confidence'];
      });

      // Redirect to chat page with the results
      if (mounted) {
        debugPrint('Navigating to ChatPage with results...');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              initialDisease: _detectedDisease,
              initialConfidence: _confidence,
              imageFile: _imageFile,
              imageUrl: widget.imageUrl,
            ),
          ),
          (route) => false, // This removes all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error in disease detection: $e');
      setState(() {
        _errorMessage = 'Error processing image: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
    debugPrint('=== Disease Detection Process Completed ===\n');
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        _processImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: ${e.toString()}';
      });
    }
  }

  Future<void> _captureImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        _processImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturing image: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Detection'),
        backgroundColor: Colors.green[800],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_detectedDisease != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Detected Disease: $_detectedDisease',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_confidence != null)
                      Text(
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick from Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _captureImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}