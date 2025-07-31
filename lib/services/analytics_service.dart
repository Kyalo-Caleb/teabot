import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/disease_report.dart';
import '../models/analytics_data.dart';
import 'regional_analysis_service.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a disease report for analytics
  static Future<void> submitDiseaseReport({
    required String disease,
    required double confidence,
    required String imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    String cropType = 'tea',
    double affectedArea = 0.0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get location if not provided
    double finalLatitude = latitude ?? 0.0;
    double finalLongitude = longitude ?? 0.0;
    String finalLocation = location ?? 'Unknown';

    try {
      if (latitude == null || longitude == null) {
        // Try to get current location
        try {
          final position = await Geolocator.getCurrentPosition();
          finalLatitude = position.latitude;
          finalLongitude = position.longitude;
        } catch (e) {
          print('Could not get current location: $e');
          // Use user's saved location from profile
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            finalLocation = userData['location'] ?? finalLocation;
          }
        }
      }

      // Submit to regional analysis service
      await RegionalAnalysisService.submitFarmerReport(
        disease: disease,
        confidence: confidence,
        imageUrl: imageUrl,
        farmLocation: finalLocation,
        latitude: finalLatitude,
        longitude: finalLongitude,
        cropType: cropType,
        affectedArea: affectedArea,
      );
    } catch (e) {
      print('Error submitting to regional analysis: $e');
    }

    // Get user's region from coordinates or profile
    String region = 'Unknown';
    String country = 'Unknown';
    
    try {
      // You could implement a reverse geocoding service here
      // For now, extract from location string or use defaults
      if (finalLocation.isNotEmpty && finalLocation != 'Unknown') {
        final locationParts = finalLocation.split(',');
        if (locationParts.length >= 2) {
          region = locationParts[locationParts.length - 2].trim();
          country = locationParts.last.trim();
        }
      }
    } catch (e) {
      print('Error processing location: $e');
    }

    final report = DiseaseReport(
      id: '', // Will be set by Firestore
      userId: user.uid,
      disease: disease,
      confidence: confidence,
      detectedAt: DateTime.now(),
      location: finalLocation,
      latitude: finalLatitude,
      longitude: finalLongitude,
      imageUrl: imageUrl,
      region: region,
      country: country,
    );

    await _firestore.collection('disease_reports').add(report.toFirestore());
  }

  // Get analytics data for the dashboard
  static Future<AnalyticsData> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
    String? region,
  }) async {
    startDate ??= DateTime.now().subtract(const Duration(days: 365));
    endDate ??= DateTime.now();

    Query query = _firestore.collection('disease_reports')
        .where('detectedAt', isGreaterThanOrEqualTo: startDate)
        .where('detectedAt', isLessThanOrEqualTo: endDate);

    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }

    final snapshot = await query.get();
    final reports = snapshot.docs.map((doc) => 
        DiseaseReport.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
    ).toList();

    return _processAnalyticsData(reports);
  }

  static AnalyticsData _processAnalyticsData(List<DiseaseReport> reports) {
    final totalReports = reports.length;
    
    // Calculate disease statistics
    final diseaseCount = <String, int>{};
    final monthlyData = <String, Map<DateTime, int>>{};
    final regionalData = <String, Map<String, int>>{};

    for (final report in reports) {
      // Disease counts
      diseaseCount[report.disease] = (diseaseCount[report.disease] ?? 0) + 1;

      // Monthly trends
      final monthKey = DateTime(report.detectedAt.year, report.detectedAt.month);
      monthlyData[report.disease] ??= {};
      monthlyData[report.disease]![monthKey] = 
          (monthlyData[report.disease]![monthKey] ?? 0) + 1;

      // Regional data
      regionalData[report.region] ??= {};
      regionalData[report.region]![report.disease] = 
          (regionalData[report.region]![report.disease] ?? 0) + 1;
    }

    // Create disease statistics
    final diseaseStats = diseaseCount.entries.map((entry) {
      final disease = entry.key;
      final count = entry.value;
      final percentage = totalReports > 0 ? (count / totalReports) * 100 : 0.0;
      
      final monthlyTrend = monthlyData[disease]?.entries.map((monthEntry) =>
          MonthlyData(
            month: monthEntry.key,
            count: monthEntry.value,
            disease: disease,
          )
      ).toList() ?? [];

      return DiseaseStatistics(
        disease: disease,
        count: count,
        percentage: percentage,
        monthlyTrend: monthlyTrend,
      );
    }).toList();

    // Create regional data
    final regionalStats = regionalData.entries.map((entry) {
      final region = entry.key;
      final diseases = entry.value;
      final totalCases = diseases.values.fold(0, (sum, count) => sum + count);
      final severity = _calculateSeverity(diseases, totalCases);

      return RegionalData(
        region: region,
        totalCases: totalCases,
        diseaseBreakdown: diseases,
        severity: severity,
      );
    }).toList();

    // Create overall trend
    final overallMonthlyData = <DateTime, int>{};
    for (final report in reports) {
      final monthKey = DateTime(report.detectedAt.year, report.detectedAt.month);
      overallMonthlyData[monthKey] = (overallMonthlyData[monthKey] ?? 0) + 1;
    }

    final overallTrend = overallMonthlyData.entries.map((entry) =>
        MonthlyData(
          month: entry.key,
          count: entry.value,
          disease: 'Total',
        )
    ).toList()..sort((a, b) => a.month.compareTo(b.month));

    return AnalyticsData(
      totalReports: totalReports,
      diseaseStats: diseaseStats,
      regionalData: regionalStats,
      overallTrend: overallTrend,
      lastUpdated: DateTime.now(),
    );
  }

  static double _calculateSeverity(Map<String, int> diseases, int totalCases) {
    // Weight diseases by severity (you can adjust these weights)
    const diseaseWeights = {
      'brown blight': 0.9,
      'grey blight': 0.7,
      'algal leaf spot': 0.5,
    };

    double weightedSum = 0.0;
    for (final entry in diseases.entries) {
      final weight = diseaseWeights[entry.key.toLowerCase()] ?? 0.5;
      weightedSum += entry.value * weight;
    }

    return totalCases > 0 ? (weightedSum / totalCases).clamp(0.0, 1.0) : 0.0;
  }

  // Get recent reports for activity feed
  static Future<List<DiseaseReport>> getRecentReports({int limit = 10}) async {
    final snapshot = await _firestore.collection('disease_reports')
        .orderBy('detectedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => 
        DiseaseReport.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
    ).toList();
  }

  // Get user's own reports
  static Future<List<DiseaseReport>> getUserReports() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore.collection('disease_reports')
        .where('userId', isEqualTo: user.uid)
        .orderBy('detectedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => 
        DiseaseReport.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
    ).toList();
  }
}