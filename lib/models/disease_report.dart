class DiseaseReport {
  final String id;
  final String userId;
  final String disease;
  final double confidence;
  final DateTime detectedAt;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final String region;
  final String country;

  DiseaseReport({
    required this.id,
    required this.userId,
    required this.disease,
    required this.confidence,
    required this.detectedAt,
    this.location,
    this.latitude,
    this.longitude,
    required this.imageUrl,
    required this.region,
    required this.country,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'disease': disease,
      'confidence': confidence,
      'detectedAt': detectedAt,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'region': region,
      'country': country,
    };
  }

  factory DiseaseReport.fromFirestore(String id, Map<String, dynamic> data) {
    return DiseaseReport(
      id: id,
      userId: data['userId'],
      disease: data['disease'],
      confidence: data['confidence'].toDouble(),
      detectedAt: data['detectedAt'].toDate(),
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      imageUrl: data['imageUrl'],
      region: data['region'] ?? 'Unknown',
      country: data['country'] ?? 'Unknown',
    );
  }
}