import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teabot/pages/disease_detection_page.dart';
import 'package:teabot/pages/analytics_page.dart';
import 'package:teabot/pages/regional_dashboard_page.dart';
import 'package:teabot/services/regional_analysis_service.dart';
import 'package:teabot/models/regional_analysis.dart';

class HomePage extends StatefulWidget {
  final String? userName;
  
  const HomePage({
    Key? key,
    this.userName,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _profileImageUrl;
  String? _displayName;
  RegionalAnalysis? _localRegionalAnalysis;
  List<OutbreakAlert> _localAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadLocalRegionalData();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _displayName = user.displayName;
      });

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        setState(() {
          _profileImageUrl = userData.data()?['profileImage'];
        });
      }
    }
  }

  Future<void> _loadLocalRegionalData() async {
    try {
      final localAnalysis = await RegionalAnalysisService.getLocalRegionalAnalysis();
      final alerts = await RegionalAnalysisService.getOutbreakAlerts(
        regionId: localAnalysis?.regionId,
        activeOnly: true,
      );
      
      setState(() {
        _localRegionalAnalysis = localAnalysis;
        _localAlerts = alerts;
      });
    } catch (e) {
      print('Error loading local regional data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final displayName = args?['userName'] ?? widget.userName ?? "User";

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with welcome message and profile
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                              : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 30),
                    onPressed: () {
                      _showImageUploadOptions(context);
                    },
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions Section
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            'Regional Analysis',
                            'View outbreak patterns in your area',
                            Icons.map,
                            Colors.blue,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegionalDashboardPage()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildQuickActionCard(
                            'Scan Leaf',
                            'Detect diseases instantly',
                            Icons.camera_alt,
                            Colors.green,
                            () => _showImageUploadOptions(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    // Local Regional Status
                    if (_localRegionalAnalysis != null) ...[
                      _buildLocalRegionalStatus(),
                      const SizedBox(height: 30),
                    ],
                    
                    // Active Alerts
                    if (_localAlerts.isNotEmpty) ...[
                      _buildActiveAlerts(),
                      const SizedBox(height: 30),
                    ],
                    
                    // Disease Overview Section
                    const Text(
                      'Disease Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Common tea leaf diseases to watch for',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Disease Info Cards
                    _buildDiseaseInfoCard(
                      'Algal Leaf Spot',
                      'Circular, raised spots with velvety texture',
                      Colors.orange,
                      Icons.circle,
                    ),
                    const SizedBox(height: 12),
                    _buildDiseaseInfoCard(
                      'Brown Blight',
                      'Brown, sunken lesions with dark borders',
                      Colors.red,
                      Icons.warning,
                    ),
                    const SizedBox(height: 12),
                    _buildDiseaseInfoCard(
                      'Grey Blight',
                      'Grey spots with concentric ring patterns',
                      Colors.grey,
                      Icons.blur_circular,
                    ),
                    const SizedBox(height: 20),
                    
                    // Recent Searches Section
                    const Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D1B20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Recent Searches Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildRecentSearchCard(),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildRecentSearchCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            _showImageUploadOptions(context);
          } else if (index == 2) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/chat');
        },
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildLocalRegionalStatus() {
    if (_localRegionalAnalysis == null) return const SizedBox();
    
    final analysis = _localRegionalAnalysis!;
    final riskColor = _getRiskColor(analysis.riskLevel);
    
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
              const Text(
                'Your Region Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRiskLabel(analysis.riskLevel),
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis.regionName,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem('Active Farmers', analysis.activeFarmers.toString()),
              ),
              Expanded(
                child: _buildStatusItem('Disease Types', analysis.diseaseOutbreaks.length.toString()),
              ),
              Expanded(
                child: _buildStatusItem('Risk Level', '${(analysis.riskLevel * 100).toInt()}%'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveAlerts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.left(color: Colors.red, width: 4),
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
            children: [
              Icon(Icons.warning, color: Colors.red[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Active Outbreak Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._localAlerts.take(2).map((alert) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getSeverityColor(alert.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${alert.disease} outbreak detected',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  alert.severity.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getSeverityColor(alert.severity),
                  ),
                ),
              ],
            ),
          )),
          if (_localAlerts.length > 2) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegionalDashboardPage()),
              ),
              child: Text('View all ${_localAlerts.length} alerts'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseInfoCard(String title, String description, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.left(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red[50],
                child: Icon(Icons.photo_library, color: Colors.red[400]),
              ),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _handleImageUpload(context);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: Icon(Icons.camera_alt, color: Colors.blue[400]),
              ),
              title: const Text('Capture Image'),
              onTap: () {
                Navigator.pop(context);
                _handleImageCapture(context);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[50],
                child: Icon(Icons.link, color: Colors.green[400]),
              ),
              title: const Text('Add from URL'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement URL upload
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[50],
                child: Icon(Icons.search, color: Colors.green[400]),
              ),
              title: const Text('Search from Web'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement web search
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageUpload(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DiseaseDetectionPage(
                imageFile: imageFile,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleImageCapture(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DiseaseDetectionPage(
                imageFile: imageFile,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildRecentSearchCard() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(20),
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
}