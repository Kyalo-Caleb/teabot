import 'package:flutter/foundation.dart';

class DiseaseInfoService {
  static final Map<String, Map<String, String>> _diseaseInfo = {
    'algal leaf spot': {
      'description': 'Algal leaf spot is a disease caused by the parasitic alga Cephaleuros virescens. It appears as circular, raised, green to gray-green spots on tea leaves.',
      'symptoms': 'Circular spots with velvety texture, green to gray-green color, spots may turn reddish-brown, leaves may become yellow and fall prematurely.',
      'causes': 'Caused by parasitic alga Cephaleuros virescens, favored by high humidity and poor air circulation.',
      'treatment': 'Apply copper-based fungicides, improve air circulation, prune affected leaves, maintain proper plant spacing.',
      'prevention': 'Maintain good air circulation, avoid overhead irrigation, regular pruning, proper plant spacing.',
      'impact': 'Reduces photosynthetic area, affects tea quality, can cause defoliation in severe cases.',
      'severity': 'Moderate to severe depending on environmental conditions.',
      'economic_impact': 'Can cause significant yield loss in tea plantations, affects tea quality and market value.',
      'control_time': 'Treatment effects visible within 2-3 weeks, complete control may take 1-2 months.',
      'natural_remedies': 'Neem oil spray, improving drainage, increasing sunlight exposure, proper pruning practices.'
    },
    'brown blight': {
      'description': 'Brown blight is a fungal disease caused by Colletotrichum camelliae. It causes brown spots on tea leaves and can severely affect tea production.',
      'symptoms': 'Brown, circular lesions with dark margins, sunken spots, leaves may curl and drop.',
      'causes': 'Fungal pathogen Colletotrichum camelliae, spread by rain splash, favored by warm and humid conditions.',
      'treatment': 'Apply fungicides, remove infected leaves, improve air circulation, reduce humidity.',
      'prevention': 'Regular pruning, proper spacing, avoid overhead irrigation, maintain field sanitation.',
      'impact': 'Affects leaf quality, reduces yield, can cause significant defoliation.',
      'severity': 'Can be severe, especially during wet seasons.',
      'economic_impact': 'Major economic losses in tea production, affects tea quality and export value.',
      'control_time': 'Initial improvement in 2-3 weeks, full control may take 2-3 months.',
      'natural_remedies': 'Bordeaux mixture, proper cultural practices, organic fungicides.'
    },
    'grey blight': {
      'description': 'Grey blight is caused by the fungus Pestalotiopsis theae. It creates characteristic grey spots with black dots on tea leaves.',
      'symptoms': 'Grey to brown spots with concentric rings, black fruiting bodies in the center, leaf margins may die.',
      'causes': 'Fungal pathogen Pestalotiopsis theae, favored by high humidity and temperature.',
      'treatment': 'Fungicide application, removal of infected parts, improve air circulation.',
      'prevention': 'Maintain proper spacing, regular pruning, avoid water stress, field sanitation.',
      'impact': 'Reduces photosynthetic area, affects tea quality, can cause premature leaf fall.',
      'severity': 'Moderate to high, can become severe in conducive conditions.',
      'economic_impact': 'Significant impact on tea yield and quality, affects market value.',
      'control_time': 'Visible improvement in 2-4 weeks, complete control in 2-3 months.',
      'natural_remedies': 'Trichoderma-based biocontrol, proper cultural practices, organic fungicides.'
    },
    'grey-blight': {
      'description': 'Grey blight is caused by the fungus Pestalotiopsis theae. It creates characteristic grey spots with black dots on tea leaves.',
      'symptoms': 'Grey to brown spots with concentric rings, black fruiting bodies in the center, leaf margins may die.',
      'causes': 'Fungal pathogen Pestalotiopsis theae, favored by high humidity and temperature.',
      'treatment': 'Fungicide application, removal of infected parts, improve air circulation.',
      'prevention': 'Maintain proper spacing, regular pruning, avoid water stress, field sanitation.',
      'impact': 'Reduces photosynthetic area, affects tea quality, can cause premature leaf fall.',
      'severity': 'Moderate to high, can become severe in conducive conditions.',
      'economic_impact': 'Significant impact on tea yield and quality, affects market value.',
      'control_time': 'Visible improvement in 2-4 weeks, complete control in 2-3 months.',
      'natural_remedies': 'Trichoderma-based biocontrol, proper cultural practices, organic fungicides.'
    }
  };

  static String getAnswer(String disease, String question) {
    debugPrint('\n=== Disease Info Service ===');
    debugPrint('Disease: $disease');
    debugPrint('Question: $question');

    try {
      // Normalize disease name by converting to lowercase and replacing hyphens with spaces
      final normalizedDisease = disease.toLowerCase().replaceAll('-', ' ');
      debugPrint('Normalized disease name: $normalizedDisease');
      
      // Get disease data
      final diseaseData = _diseaseInfo[normalizedDisease];
      if (diseaseData == null) {
        throw Exception('Disease information not found');
      }

      String? answer;
      final normalizedQuestion = question.toLowerCase();
      
      if (normalizedQuestion.contains('what is')) {
        answer = diseaseData['description'];
      } else if (normalizedQuestion.contains('symptoms')) {
        answer = diseaseData['symptoms'];
      } else if (normalizedQuestion.contains('cause')) {
        answer = diseaseData['causes'];
      } else if (normalizedQuestion.contains('treat')) {
        answer = diseaseData['treatment'];
      } else if (normalizedQuestion.contains('prevent')) {
        answer = diseaseData['prevention'];
      } else if (normalizedQuestion.contains('impact') || normalizedQuestion.contains('affect') || normalizedQuestion.contains('effect')) {
        answer = diseaseData['impact'];
      } else if (normalizedQuestion.contains('severe')) {
        answer = diseaseData['severity'];
      } else if (normalizedQuestion.contains('economic')) {
        answer = diseaseData['economic_impact'];
      } else if (normalizedQuestion.contains('control') || normalizedQuestion.contains('time')) {
        answer = diseaseData['control_time'];
      } else if (normalizedQuestion.contains('natural') || normalizedQuestion.contains('remedies')) {
        answer = diseaseData['natural_remedies'];
      }

      if (answer == null) {
        throw Exception('No specific answer found for this question');
      }

      debugPrint('Answer found');
      debugPrint('=== Disease Info Service Complete ===\n');
      return answer;
    } catch (e) {
      debugPrint('Error: $e');
      debugPrint('=== Disease Info Service Error ===\n');
      return 'I apologize, but I don\'t have enough information to answer that specific question about $disease. Please try asking another question or rephrase your question.';
    }
  }
} 