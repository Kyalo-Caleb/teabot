import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/regional_analysis.dart';
import '../models/disease_report.dart';
import 'dart:math' as math;

class RegionalAnalysisService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a farmer's disease report
  static Future<void> submitFarmerReport({
    required String disease,
    required double confidence,
    required String imageUrl,
    required String farmLocation,
    required double latitude,
    required double longitude,
    String cropType = 'tea',
    double affectedArea = 0.0,
    Map<String, dynamic>? additionalData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get farmer profile
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final farmerName = userData['name'] ?? user.displayName ?? 'Unknown Farmer';

    final report = FarmerReport(
      farmerId: user.uid,
      farmerName: farmerName,
      farmLocation: farmLocation,
      latitude: latitude,
      longitude: longitude,
      disease: disease,
      confidence: confidence,
      reportedAt: DateTime.now(),
      imageUrl: imageUrl,
      cropType: cropType,
      affectedArea: affectedArea,
      additionalData: additionalData ?? {},
    );

    // Save the farmer report
    await _firestore.collection('farmer_reports').add(report.toFirestore());

    // Update regional analysis
    await _updateRegionalAnalysis(report);

    // Check for outbreak conditions
    await _checkForOutbreaks(report);
  }

  // Get regional analysis for a specific region
  static Future<RegionalAnalysis?> getRegionalAnalysis(String regionId) async {
    final doc = await _firestore.collection('regional_analysis').doc(regionId).get();
    if (!doc.exists) return null;
    return RegionalAnalysis.fromFirestore(doc);
  }

  // Get all regional analyses
  static Future<List<RegionalAnalysis>> getAllRegionalAnalyses() async {
    final snapshot = await _firestore.collection('regional_analysis').get();
    return snapshot.docs.map((doc) => RegionalAnalysis.fromFirestore(doc)).toList();
  }

  // Get regional analysis for user's area
  static Future<RegionalAnalysis?> getLocalRegionalAnalysis() async {
    try {
      final position = await _getCurrentPosition();
      final regionId = await _getRegionIdFromCoordinates(position.latitude, position.longitude);
      if (regionId != null) {
        return await getRegionalAnalysis(regionId);
      }
    } catch (e) {
      print('Error getting local regional analysis: $e');
    }
    return null;
  }

  // Get farmer reports for a region
  static Future<List<FarmerReport>> getFarmerReports({
    String? regionId,
    DateTime? startDate,
    DateTime? endDate,
    String? disease,
    int limit = 50,
  }) async {
    Query query = _firestore.collection('farmer_reports');

    if (regionId != null) {
      // Get reports within region bounds
      final regionDoc = await _firestore.collection('regions').doc(regionId).get();
      if (regionDoc.exists) {
        final regionData = regionDoc.data()!;
        final bounds = regionData['bounds'] as Map<String, dynamic>;
        query = query
            .where('latitude', isGreaterThanOrEqualTo: bounds['south'])
            .where('latitude', isLessThanOrEqualTo: bounds['north'])
            .where('longitude', isGreaterThanOrEqualTo: bounds['west'])
            .where('longitude', isLessThanOrEqualTo: bounds['east']);
      }
    }

    if (startDate != null) {
      query = query.where('reportedAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('reportedAt', isLessThanOrEqualTo: endDate);
    }

    if (disease != null) {
      query = query.where('disease', isEqualTo: disease);
    }

    query = query.orderBy('reportedAt', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => FarmerReport.fromFirestore(doc)).toList();
  }

  // Get outbreak alerts for a region
  static Future<List<OutbreakAlert>> getOutbreakAlerts({
    String? regionId,
    bool activeOnly = true,
  }) async {
    Query query = _firestore.collection('outbreak_alerts');

    if (regionId != null) {
      query = query.where('regionId', isEqualTo: regionId);
    }

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    query = query.orderBy('createdAt', descending: true);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => OutbreakAlert.fromFirestore(doc)).toList();
  }

  // Update regional analysis based on new farmer report
  static Future<void> _updateRegionalAnalysis(FarmerReport report) async {
    final regionId = await _getRegionIdFromCoordinates(report.latitude, report.longitude);
    if (regionId == null) return;

    final regionRef = _firestore.collection('regional_analysis').doc(regionId);
    
    await _firestore.runTransaction((transaction) async {
      final regionDoc = await transaction.get(regionRef);
      
      RegionalAnalysis? currentAnalysis;
      if (regionDoc.exists) {
        currentAnalysis = RegionalAnalysis.fromFirestore(regionDoc);
      }

      // Calculate updated analysis
      final updatedAnalysis = await _calculateUpdatedAnalysis(
        currentAnalysis,
        report,
        regionId,
      );

      transaction.set(regionRef, updatedAnalysis.toFirestore());
    });
  }

  // Calculate updated regional analysis
  static Future<RegionalAnalysis> _calculateUpdatedAnalysis(
    RegionalAnalysis? current,
    FarmerReport newReport,
    String regionId,
  ) async {
    // Get all reports for this region in the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentReports = await getFarmerReports(
      regionId: regionId,
      startDate: thirtyDaysAgo,
    );

    // Add the new report to the list
    recentReports.add(newReport);

    // Calculate disease outbreaks
    final diseaseOutbreaks = <String, DiseaseOutbreakData>{};
    final diseaseGroups = <String, List<FarmerReport>>{};

    // Group reports by disease
    for (final report in recentReports) {
      diseaseGroups[report.disease] ??= [];
      diseaseGroups[report.disease]!.add(report);
    }

    // Calculate outbreak data for each disease
    for (final entry in diseaseGroups.entries) {
      final disease = entry.key;
      final reports = entry.value;
      
      final totalCases = reports.length;
      final newCasesThisWeek = reports.where((r) => 
        r.reportedAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))
      ).length;
      
      final averageConfidence = reports.isNotEmpty
          ? reports.map((r) => r.confidence).reduce((a, b) => a + b) / reports.length
          : 0.0;

      final sortedReports = reports..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));
      final firstDetected = sortedReports.first.reportedAt;
      final lastDetected = sortedReports.last.reportedAt;

      final affectedFarms = reports.map((r) => r.farmerId).toSet().toList();
      
      final severity = _calculateOutbreakSeverity(totalCases, newCasesThisWeek, affectedFarms.length);
      
      // Calculate weekly trend
      final weeklyTrend = <String, int>{};
      for (int i = 0; i < 4; i++) {
        final weekStart = DateTime.now().subtract(Duration(days: (i + 1) * 7));
        final weekEnd = DateTime.now().subtract(Duration(days: i * 7));
        final weekKey = 'week_$i';
        weeklyTrend[weekKey] = reports.where((r) => 
          r.reportedAt.isAfter(weekStart) && r.reportedAt.isBefore(weekEnd)
        ).length;
      }

      diseaseOutbreaks[disease] = DiseaseOutbreakData(
        disease: disease,
        totalCases: totalCases,
        newCasesThisWeek: newCasesThisWeek,
        averageConfidence: averageConfidence,
        firstDetected: firstDetected,
        lastDetected: lastDetected,
        affectedFarms: affectedFarms,
        severity: severity,
        weeklyTrend: weeklyTrend,
      );
    }

    // Calculate overall risk level
    final riskLevel = _calculateRegionalRiskLevel(diseaseOutbreaks);

    // Get unique farmers and affected areas
    final uniqueFarmers = recentReports.map((r) => r.farmerId).toSet();
    final affectedAreas = recentReports.map((r) => r.farmLocation).toSet().toList();

    // Calculate crop types
    final cropTypes = <String, int>{};
    for (final report in recentReports) {
      cropTypes[report.cropType] = (cropTypes[report.cropType] ?? 0) + 1;
    }

    // Get region information
    final regionDoc = await _firestore.collection('regions').doc(regionId).get();
    final regionData = regionDoc.data() ?? {};

    return RegionalAnalysis(
      regionId: regionId,
      regionName: regionData['name'] ?? 'Unknown Region',
      country: regionData['country'] ?? 'Unknown',
      latitude: (regionData['latitude'] ?? 0.0).toDouble(),
      longitude: (regionData['longitude'] ?? 0.0).toDouble(),
      totalFarmers: regionData['totalFarmers'] ?? uniqueFarmers.length,
      activeFarmers: uniqueFarmers.length,
      diseaseOutbreaks: diseaseOutbreaks,
      riskLevel: riskLevel,
      lastUpdated: DateTime.now(),
      affectedAreas: affectedAreas,
      cropTypes: cropTypes,
    );
  }

  // Calculate outbreak severity
  static OutbreakSeverity _calculateOutbreakSeverity(
    int totalCases,
    int newCasesThisWeek,
    int affectedFarms,
  ) {
    // Define thresholds for outbreak severity
    if (newCasesThisWeek >= 10 || affectedFarms >= 5) {
      return OutbreakSeverity.critical;
    } else if (newCasesThisWeek >= 5 || affectedFarms >= 3) {
      return OutbreakSeverity.high;
    } else if (newCasesThisWeek >= 2 || affectedFarms >= 2) {
      return OutbreakSeverity.moderate;
    } else {
      return OutbreakSeverity.low;
    }
  }

  // Calculate regional risk level
  static double _calculateRegionalRiskLevel(Map<String, DiseaseOutbreakData> outbreaks) {
    if (outbreaks.isEmpty) return 0.0;

    double totalRisk = 0.0;
    int riskFactors = 0;

    for (final outbreak in outbreaks.values) {
      double diseaseRisk = 0.0;
      
      // Factor in severity
      switch (outbreak.severity) {
        case OutbreakSeverity.critical:
          diseaseRisk += 0.4;
          break;
        case OutbreakSeverity.high:
          diseaseRisk += 0.3;
          break;
        case OutbreakSeverity.moderate:
          diseaseRisk += 0.2;
          break;
        case OutbreakSeverity.low:
          diseaseRisk += 0.1;
          break;
      }

      // Factor in spread rate (new cases this week vs total cases)
      if (outbreak.totalCases > 0) {
        final spreadRate = outbreak.newCasesThisWeek / outbreak.totalCases;
        diseaseRisk += spreadRate * 0.3;
      }

      // Factor in number of affected farms
      final farmSpread = math.min(outbreak.affectedFarms.length / 10.0, 1.0);
      diseaseRisk += farmSpread * 0.3;

      totalRisk += diseaseRisk;
      riskFactors++;
    }

    return riskFactors > 0 ? math.min(totalRisk / riskFactors, 1.0) : 0.0;
  }

  // Check for outbreak conditions and create alerts
  static Future<void> _checkForOutbreaks(FarmerReport report) async {
    final regionId = await _getRegionIdFromCoordinates(report.latitude, report.longitude);
    if (regionId == null) return;

    // Get recent reports for the same disease in the region
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentReports = await getFarmerReports(
      regionId: regionId,
      disease: report.disease,
      startDate: weekAgo,
    );

    // Check if outbreak conditions are met
    final uniqueFarms = recentReports.map((r) => r.farmerId).toSet();
    final newCasesThisWeek = recentReports.length;

    bool shouldCreateAlert = false;
    OutbreakSeverity severity = OutbreakSeverity.low;
    String message = '';

    if (newCasesThisWeek >= 10 && uniqueFarms.length >= 5) {
      shouldCreateAlert = true;
      severity = OutbreakSeverity.critical;
      message = 'CRITICAL OUTBREAK: ${report.disease} detected in $newCasesThisWeek cases across ${uniqueFarms.length} farms in the past week.';
    } else if (newCasesThisWeek >= 5 && uniqueFarms.length >= 3) {
      shouldCreateAlert = true;
      severity = OutbreakSeverity.high;
      message = 'HIGH RISK OUTBREAK: ${report.disease} spreading rapidly with $newCasesThisWeek cases across ${uniqueFarms.length} farms.';
    } else if (newCasesThisWeek >= 3 && uniqueFarms.length >= 2) {
      shouldCreateAlert = true;
      severity = OutbreakSeverity.moderate;
      message = 'MODERATE OUTBREAK: ${report.disease} detected in multiple farms. Monitor closely.';
    }

    if (shouldCreateAlert) {
      // Check if there's already an active alert for this disease in this region
      final existingAlerts = await getOutbreakAlerts(
        regionId: regionId,
        activeOnly: true,
      );

      final hasActiveAlert = existingAlerts.any((alert) => 
        alert.disease == report.disease && alert.severity.index >= severity.index
      );

      if (!hasActiveAlert) {
        await _createOutbreakAlert(
          regionId: regionId,
          disease: report.disease,
          severity: severity,
          message: message,
          affectedAreas: recentReports.map((r) => r.farmLocation).toSet().toList(),
        );
      }
    }
  }

  // Create outbreak alert
  static Future<void> _createOutbreakAlert({
    required String regionId,
    required String disease,
    required OutbreakSeverity severity,
    required String message,
    required List<String> affectedAreas,
  }) async {
    final recommendations = _getOutbreakRecommendations(disease, severity);
    
    final alert = OutbreakAlert(
      alertId: '',
      regionId: regionId,
      disease: disease,
      severity: severity,
      message: message,
      createdAt: DateTime.now(),
      isActive: true,
      affectedAreas: affectedAreas,
      recommendations: recommendations,
    );

    await _firestore.collection('outbreak_alerts').add(alert.toFirestore());
  }

  // Get outbreak recommendations
  static Map<String, String> _getOutbreakRecommendations(String disease, OutbreakSeverity severity) {
    final baseRecommendations = {
      'algal leaf spot': {
        'immediate': 'Remove affected leaves immediately and improve air circulation',
        'treatment': 'Apply copper-based fungicides and reduce humidity',
        'prevention': 'Maintain proper plant spacing and avoid overhead irrigation',
      },
      'brown blight': {
        'immediate': 'Isolate affected plants and remove infected material',
        'treatment': 'Apply systemic fungicides and improve drainage',
        'prevention': 'Regular field sanitation and proper pruning practices',
      },
      'grey blight': {
        'immediate': 'Remove infected leaves and improve air circulation',
        'treatment': 'Apply appropriate fungicides and reduce leaf wetness',
        'prevention': 'Maintain field hygiene and proper plant spacing',
      },
    };

    final diseaseRecs = baseRecommendations[disease.toLowerCase()] ?? {
      'immediate': 'Consult agricultural extension officer immediately',
      'treatment': 'Follow recommended treatment protocols',
      'prevention': 'Implement preventive measures as advised',
    };

    // Add severity-specific recommendations
    if (severity == OutbreakSeverity.critical) {
      diseaseRecs['urgent'] = 'Contact agricultural authorities immediately. Consider quarantine measures.';
    } else if (severity == OutbreakSeverity.high) {
      diseaseRecs['urgent'] = 'Implement immediate control measures and monitor spread closely.';
    }

    return diseaseRecs;
  }

  // Get current position
  static Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Get region ID from coordinates
  static Future<String?> _getRegionIdFromCoordinates(double latitude, double longitude) async {
    // Query regions collection to find which region contains these coordinates
    final regionsSnapshot = await _firestore.collection('regions').get();
    
    for (final regionDoc in regionsSnapshot.docs) {
      final regionData = regionDoc.data();
      final bounds = regionData['bounds'] as Map<String, dynamic>?;
      
      if (bounds != null) {
        final north = bounds['north']?.toDouble() ?? 0.0;
        final south = bounds['south']?.toDouble() ?? 0.0;
        final east = bounds['east']?.toDouble() ?? 0.0;
        final west = bounds['west']?.toDouble() ?? 0.0;
        
        if (latitude >= south && latitude <= north && 
            longitude >= west && longitude <= east) {
          return regionDoc.id;
        }
      }
    }

    // If no region found, create a default region based on coordinates
    return await _createRegionFromCoordinates(latitude, longitude);
  }

  // Create a new region from coordinates
  static Future<String> _createRegionFromCoordinates(double latitude, double longitude) async {
    // Create a region with approximate bounds (±0.1 degrees)
    final regionData = {
      'name': 'Region ${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}',
      'country': 'Unknown', // You could use a geocoding service here
      'latitude': latitude,
      'longitude': longitude,
      'bounds': {
        'north': latitude + 0.1,
        'south': latitude - 0.1,
        'east': longitude + 0.1,
        'west': longitude - 0.1,
      },
      'totalFarmers': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('regions').add(regionData);
    return docRef.id;
  }

  // Get nearby regions for comparison
  static Future<List<RegionalAnalysis>> getNearbyRegions(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    // Calculate approximate bounds
    final latDelta = radiusKm / 111.0; // Approximate km per degree latitude
    final lonDelta = radiusKm / (111.0 * math.cos(latitude * math.pi / 180));

    final analyses = await getAllRegionalAnalyses();
    
    return analyses.where((analysis) {
      final distance = _calculateDistance(
        latitude, longitude,
        analysis.latitude, analysis.longitude,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two points
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Deactivate outbreak alert
  static Future<void> deactivateOutbreakAlert(String alertId) async {
    await _firestore.collection('outbreak_alerts').doc(alertId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get outbreak statistics for dashboard
  static Future<Map<String, dynamic>> getOutbreakStatistics() async {
    final activeAlerts = await getOutbreakAlerts(activeOnly: true);
    final allRegions = await getAllRegionalAnalyses();
    
    final criticalRegions = allRegions.where((r) => r.riskLevel >= 0.7).length;
    final highRiskRegions = allRegions.where((r) => r.riskLevel >= 0.4 && r.riskLevel < 0.7).length;
    
    final diseaseBreakdown = <String, int>{};
    for (final alert in activeAlerts) {
      diseaseBreakdown[alert.disease] = (diseaseBreakdown[alert.disease] ?? 0) + 1;
    }

    return {
      'totalActiveAlerts': activeAlerts.length,
      'criticalRegions': criticalRegions,
      'highRiskRegions': highRiskRegions,
      'totalRegions': allRegions.length,
      'diseaseBreakdown': diseaseBreakdown,
      'lastUpdated': DateTime.now(),
    };
  }
}