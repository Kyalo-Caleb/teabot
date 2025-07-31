import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/regional_analysis_service.dart';
import '../models/regional_analysis.dart';
import 'package:intl/intl.dart';

class RegionalDashboardPage extends StatefulWidget {
  const RegionalDashboardPage({Key? key}) : super(key: key);

  @override
  _RegionalDashboardPageState createState() => _RegionalDashboardPageState();
}

class _RegionalDashboardPageState extends State<RegionalDashboardPage> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<RegionalAnalysis> _regionalAnalyses = [];
  List<OutbreakAlert> _activeAlerts = [];
  Map<String, dynamic>? _outbreakStats;
  bool _isLoading = true;
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final analyses = await RegionalAnalysisService.getAllRegionalAnalyses();
      final alerts = await RegionalAnalysisService.getOutbreakAlerts();
      final stats = await RegionalAnalysisService.getOutbreakStatistics();
      
      setState(() {
        _regionalAnalyses = analyses;
        _activeAlerts = alerts;
        _outbreakStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Regional Disease Analysis', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showAlertsDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[800],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.green[800],
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Regions'),
            Tab(text: 'Outbreaks'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRegionsTab(),
                _buildOutbreaksTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsOverview(),
          const SizedBox(height: 24),
          _buildRiskLevelChart(),
          const SizedBox(height: 24),
          _buildRecentAlerts(),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    if (_outbreakStats == null) return const SizedBox();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Active Alerts',
            _outbreakStats!['totalActiveAlerts'].toString(),
            Icons.warning,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Critical Regions',
            _outbreakStats!['criticalRegions'].toString(),
            Icons.dangerous,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Regions',
            _outbreakStats!['totalRegions'].toString(),
            Icons.location_on,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelChart() {
    if (_regionalAnalyses.isEmpty) return const SizedBox();

    final riskData = _regionalAnalyses.map((analysis) {
      return FlSpot(
        _regionalAnalyses.indexOf(analysis).toDouble(),
        analysis.riskLevel,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Regional Risk Levels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _regionalAnalyses.length) {
                          final region = _regionalAnalyses[index];
                          return Text(
                            region.regionName.length > 8 
                                ? '${region.regionName.substring(0, 8)}...'
                                : region.regionName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: riskData,
                    isCurved: true,
                    color: Colors.red[600]!,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final riskLevel = spot.y;
                        Color dotColor = Colors.green;
                        if (riskLevel >= 0.7) dotColor = Colors.red;
                        else if (riskLevel >= 0.4) dotColor = Colors.orange;
                        
                        return FlDotCirclePainter(
                          radius: 4,
                          color: dotColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red[600]!.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _regionalAnalyses.length,
      itemBuilder: (context, index) {
        final analysis = _regionalAnalyses[index];
        return _buildRegionCard(analysis);
      },
    );
  }

  Widget _buildRegionCard(RegionalAnalysis analysis) {
    final riskColor = _getRiskColor(analysis.riskLevel);
    final riskLabel = _getRiskLabel(analysis.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.regionName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      analysis.country,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRegionStat('Active Farmers', analysis.activeFarmers.toString()),
              ),
              Expanded(
                child: _buildRegionStat('Disease Types', analysis.diseaseOutbreaks.length.toString()),
              ),
              Expanded(
                child: _buildRegionStat('Affected Areas', analysis.affectedAreas.length.toString()),
              ),
            ],
          ),
          if (analysis.diseaseOutbreaks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Active Disease Outbreaks:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.diseaseOutbreaks.values.map((outbreak) => 
              _buildDiseaseOutbreakItem(outbreak)
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Last updated: ${DateFormat('MMM dd, yyyy • HH:mm').format(analysis.lastUpdated)}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseOutbreakItem(DiseaseOutbreakData outbreak) {
    final severityColor = _getSeverityColor(outbreak.severity);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outbreak.disease,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${outbreak.totalCases} cases',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (outbreak.newCasesThisWeek > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${outbreak.newCasesThisWeek}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutbreaksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeAlerts.length,
      itemBuilder: (context, index) {
        final alert = _activeAlerts[index];
        return _buildOutbreakAlertCard(alert);
      },
    );
  }

  Widget _buildOutbreakAlertCard(OutbreakAlert alert) {
    final severityColor = _getSeverityColor(alert.severity);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.left(color: severityColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  alert.severity.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM dd, HH:mm').format(alert.createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.disease.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (alert.affectedAreas.isNotEmpty) ...[
            Text(
              'Affected Areas:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: alert.affectedAreas.take(3).map((area) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  area,
                  style: const TextStyle(fontSize: 11),
                ),
              )).toList(),
            ),
          ],
          if (alert.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text(
                'Recommendations',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              children: alert.recommendations.entries.map((entry) => 
                ListTile(
                  dense: true,
                  title: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() {
    final recentAlerts = _activeAlerts.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentAlerts.isEmpty)
            const Text(
              'No active alerts',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...recentAlerts.map((alert) => _buildAlertListItem(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertListItem(OutbreakAlert alert) {
    final severityColor = _getSeverityColor(alert.severity);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.disease,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(alert.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(double riskLevel) {
    if (riskLevel >= 0.7) return Colors.red;
    if (riskLevel >= 0.4) return Colors.orange;
    return Colors.green;
  }

  String _getRiskLabel(double riskLevel) {
    if (riskLevel >= 0.7) return 'High Risk';
    if (riskLevel >= 0.4) return 'Medium Risk';
    return 'Low Risk';
  }

  Color _getSeverityColor(OutbreakSeverity severity) {
    switch (severity) {
      case OutbreakSeverity.critical:
        return Colors.red[800]!;
      case OutbreakSeverity.high:
        return Colors.red[600]!;
      case OutbreakSeverity.moderate:
        return Colors.orange[600]!;
      case OutbreakSeverity.low:
        return Colors.green[600]!;
    }
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Outbreak Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _activeAlerts.length,
            itemBuilder: (context, index) {
              final alert = _activeAlerts[index];
              return ListTile(
                leading: Icon(
                  Icons.warning,
                  color: _getSeverityColor(alert.severity),
                ),
                title: Text(alert.disease),
                subtitle: Text(alert.message),
                trailing: Text(
                  DateFormat('MMM dd').format(alert.createdAt),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}