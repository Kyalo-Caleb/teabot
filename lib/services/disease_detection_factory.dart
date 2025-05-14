import 'package:flutter/foundation.dart';
import 'disease_detection_interface.dart';

// Import implementations
import 'disease_detection_service.dart'
    if (dart.library.html) 'disease_detection_service_web.dart';

class DiseaseDetectionFactory {
  static DiseaseDetectionInterface create() {
    if (kIsWeb) {
      debugPrint('Creating web implementation of disease detection service');
    } else {
      debugPrint('Creating native implementation of disease detection service');
    }
    return DiseaseDetectionService();
  }
} 