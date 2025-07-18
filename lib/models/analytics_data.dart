class DiseaseStatistics {
  final String disease;
  final int count;
  final double percentage;
  final List<MonthlyData> monthlyTrend;

  DiseaseStatistics({
    required this.disease,
    required this.count,
    required this.percentage,
    required this.monthlyTrend,
  });
}

class MonthlyData {
  final DateTime month;
  final int count;
  final String disease;

  MonthlyData({
    required this.month,
    required this.count,
    required this.disease,
  });
}

class RegionalData {
  final String region;
  final int totalCases;
  final Map<String, int> diseaseBreakdown;
  final double severity; // 0.0 to 1.0

  RegionalData({
    required this.region,
    required this.totalCases,
    required this.diseaseBreakdown,
    required this.severity,
  });
}

class AnalyticsData {
  final int totalReports;
  final List<DiseaseStatistics> diseaseStats;
  final List<RegionalData> regionalData;
  final List<MonthlyData> overallTrend;
  final DateTime lastUpdated;

  AnalyticsData({
    required this.totalReports,
    required this.diseaseStats,
    required this.regionalData,
    required this.overallTrend,
    required this.lastUpdated,
  });
}