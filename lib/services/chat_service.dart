class ChatService {
  static Future<String> getResponse({
    required String message,
    String? disease,
  }) async {
    // TODO: Implement actual chat service with AI/ML model
    // For now, return mock responses based on the disease
    if (disease == null) {
      return "I can help you with information about tea diseases. Please upload an image first.";
    }

    final lowerMessage = message.toLowerCase();
    final lowerDisease = disease.toLowerCase();

    // Mock responses based on common questions
    if (lowerMessage.contains('what is') || lowerMessage.contains('what\'s')) {
      return _getDiseaseDescription(lowerDisease);
    } else if (lowerMessage.contains('symptom')) {
      return _getDiseaseSymptoms(lowerDisease);
    } else if (lowerMessage.contains('treat') || lowerMessage.contains('cure')) {
      return _getDiseaseTreatment(lowerDisease);
    } else if (lowerMessage.contains('cause')) {
      return _getDiseaseCauses(lowerDisease);
    } else {
      return "I can help you understand more about $disease. Try asking about its symptoms, causes, or treatment.";
    }
  }

  static String _getDiseaseDescription(String disease) {
    final descriptions = {
      'algal leaf spot': 'Algal leaf spot is a disease caused by the pathogen Cephaleuros virescens. It appears as circular, raised spots on tea leaves with a velvety texture.',
      'brown blight': 'Brown blight is a fungal disease caused by Colletotrichum camelliae. It manifests as brown, sunken lesions on tea leaves and can cause significant yield loss.',
      'grey blight': 'Grey blight is caused by Pestalotiopsis theae fungus. It appears as greyish-brown spots with dark margins on tea leaves.',
    };
    return descriptions[disease] ?? 'I don\'t have specific information about this disease.';
  }

  static String _getDiseaseSymptoms(String disease) {
    final symptoms = {
      'algal leaf spot': 'Symptoms include circular, raised spots with a velvety texture, usually green to orange in color. The spots may merge to form larger patches.',
      'brown blight': 'Symptoms include brown, sunken lesions on leaves, often with a dark border. The disease can affect both young and mature leaves.',
      'grey blight': 'Symptoms include greyish-brown spots with dark margins on leaves. The spots may have a concentric ring pattern.',
    };
    return symptoms[disease] ?? 'I don\'t have specific information about the symptoms of this disease.';
  }

  static String _getDiseaseTreatment(String disease) {
    final treatments = {
      'algal leaf spot': 'Treatment includes improving air circulation, reducing leaf wetness, and applying copper-based fungicides. Regular pruning can help manage the disease.',
      'brown blight': 'Treatment involves removing infected leaves, improving drainage, and applying fungicides like carbendazim. Cultural practices like proper spacing can help prevent the disease.',
      'grey blight': 'Treatment includes removing infected leaves, improving air circulation, and applying fungicides like mancozeb. Regular pruning and proper plant spacing can help prevent the disease.',
    };
    return treatments[disease] ?? 'I don\'t have specific information about treating this disease.';
  }

  static String _getDiseaseCauses(String disease) {
    final causes = {
      'algal leaf spot': 'The disease is caused by the alga Cephaleuros virescens, which thrives in warm, humid conditions with poor air circulation.',
      'brown blight': 'The disease is caused by the fungus Colletotrichum camelliae, which spreads through infected plant debris and thrives in warm, humid conditions.',
      'grey blight': 'The disease is caused by the fungus Pestalotiopsis theae, which spreads through wind and rain splash, and thrives in warm, humid conditions.',
    };
    return causes[disease] ?? 'I don\'t have specific information about the causes of this disease.';
  }
} 