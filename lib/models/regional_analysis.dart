import 'package:cloud_firestore/cloud_firestore.dart';

class RegionalAnalysis {
  final String regionId;
  final String regionName;
  final String country;
  final double latitude;
  final double longitude;
  final int totalFarmers;
  final int activeFarmers;
  final Map<String, DiseaseOutbreakData> diseaseOutbreaks;
  final double riskLevel; // 0.0 to 1.0
  final DateTime lastUpdated;
  final List<String> affectedAreas;
  final Map<String, int> cropTypes;

  RegionalAnalysis({
    required this.regionId,
    required this.regionName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.totalFarmers,
    required this.activeFarmers,
    required this.diseaseOutbreaks,
    required this.riskLevel,
    required this.lastUpdated,
    required this.affectedAreas,
    required this.cropTypes,
  });

  factory RegionalAnalysis.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final diseaseOutbreaksMap = <String, DiseaseOutbreakData>{};
    if (data['diseaseOutbreaks'] != null) {
      final outbreaksData = data['diseaseOutbreaks'] as Map<String, dynamic>;
      outbreaksData.forEach((disease, outbreakData) {
        diseaseOutbreaksMap[disease] = DiseaseOutbreakData.fromMap(outbreakData);
      });
    }

    return RegionalAnalysis(
      regionId: doc.id,
      regionName: data['regionName'] ?? '',
      country: data['country'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      totalFarmers: data['totalFarmers'] ?? 0,
      activeFarmers: data['activeFarmers'] ?? 0,
      diseaseOutbreaks: diseaseOutbreaksMap,
      riskLevel: (data['riskLevel'] ?? 0.0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      affectedAreas: List<String>.from(data['affectedAreas'] ?? []),
      cropTypes: Map<String, int>.from(data['cropTypes'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    final diseaseOutbreaksMap = <String, dynamic>{};
    diseaseOutbreaks.forEach((disease, outbreakData) {
      diseaseOutbreaksMap[disease] = outbreakData.toMap();
    });

    return {
      'regionName': regionName,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'totalFarmers': totalFarmers,
      'activeFarmers': activeFarmers,
      'diseaseOutbreaks': diseaseOutbreaksMap,
      'riskLevel': riskLevel,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'affectedAreas': affectedAreas,
      'cropTypes': cropTypes,
    };
  }
}

class DiseaseOutbreakData {
  final String disease;
  final int totalCases;
  final int newCasesThisWeek;
  final double averageConfidence;
  final DateTime firstDetected;
  final DateTime lastDetected;
  final List<String> affectedFarms;
  final OutbreakSeverity severity;
  final Map<String, int> weeklyTrend; // week -> case count

  DiseaseOutbreakData({
    required this.disease,
    required this.totalCases,
    required this.newCasesThisWeek,
    required this.averageConfidence,
    required this.firstDetected,
    required this.lastDetected,
    required this.affectedFarms,
    required this.severity,
    required this.weeklyTrend,
  });

  factory DiseaseOutbreakData.fromMap(Map<String, dynamic> data) {
    return DiseaseOutbreakData(
      disease: data['disease'] ?? '',
      totalCases: data['totalCases'] ?? 0,
      newCasesThisWeek: data['newCasesThisWeek'] ?? 0,
      averageConfidence: (data['averageConfidence'] ?? 0.0).toDouble(),
      firstDetected: (data['firstDetected'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastDetected: (data['lastDetected'] as Timestamp?)?.toDate() ?? DateTime.now(),
      affectedFarms: List<String>.from(data['affectedFarms'] ?? []),
      severity: OutbreakSeverity.values.firstWhere(
        (s) => s.toString() == data['severity'],
        orElse: () => OutbreakSeverity.low,
      ),
      weeklyTrend: Map<String, int>.from(data['weeklyTrend'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'disease': disease,
      'totalCases': totalCases,
      'newCasesThisWeek': newCasesThisWeek,
      'averageConfidence': averageConfidence,
      'firstDetected': Timestamp.fromDate(firstDetected),
      'lastDetected': Timestamp.fromDate(lastDetected),
      'affectedFarms': affectedFarms,
      'severity': severity.toString(),
      'weeklyTrend': weeklyTrend,
    };
  }
}

enum OutbreakSeverity {
  low,
  moderate,
  high,
  critical,
}

class FarmerReport {
  final String farmerId;
  final String farmerName;
  final String farmLocation;
  final double latitude;
  final double longitude;
  final String disease;
  final double confidence;
  final DateTime reportedAt;
  final String imageUrl;
  final String cropType;
  final double affectedArea; // in hectares
  final Map<String, dynamic> additionalData;

  FarmerReport({
    required this.farmerId,
    required this.farmerName,
    required this.farmLocation,
    required this.latitude,
    required this.longitude,
    required this.disease,
    required this.confidence,
    required this.reportedAt,
    required this.imageUrl,
    required this.cropType,
    required this.affectedArea,
    required this.additionalData,
  });

  factory FarmerReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FarmerReport(
      farmerId: data['farmerId'] ?? '',
      farmerName: data['farmerName'] ?? '',
      farmLocation: data['farmLocation'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      disease: data['disease'] ?? '',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
      cropType: data['cropType'] ?? 'tea',
      affectedArea: (data['affectedArea'] ?? 0.0).toDouble(),
      additionalData: Map<String, dynamic>.from(data['additionalData'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'farmLocation': farmLocation,
      'latitude': latitude,
      'longitude': longitude,
      'disease': disease,
      'confidence': confidence,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'imageUrl': imageUrl,
      'cropType': cropType,
      'affectedArea': affectedArea,
      'additionalData': additionalData,
    };
  }
}

class OutbreakAlert {
  final String alertId;
  final String regionId;
  final String disease;
  final OutbreakSeverity severity;
  final String message;
  final DateTime createdAt;
  final bool isActive;
  final List<String> affectedAreas;
  final Map<String, String> recommendations;

  OutbreakAlert({
    required this.alertId,
    required this.regionId,
    required this.disease,
    required this.severity,
    required this.message,
    required this.createdAt,
    required this.isActive,
    required this.affectedAreas,
    required this.recommendations,
  });

  factory OutbreakAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OutbreakAlert(
      alertId: doc.id,
      regionId: data['regionId'] ?? '',
      disease: data['disease'] ?? '',
      severity: OutbreakSeverity.values.firstWhere(
        (s) => s.toString() == data['severity'],
        orElse: () => OutbreakSeverity.low,
      ),
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      affectedAreas: List<String>.from(data['affectedAreas'] ?? []),
      recommendations: Map<String, String>.from(data['recommendations'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'regionId': regionId,
      'disease': disease,
      'severity': severity.toString(),
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'affectedAreas': affectedAreas,
      'recommendations': recommendations,
    };
  }
}