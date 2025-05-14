import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isQuestion;
  final String? imageUrl;
  final String? userId;
  final bool isSynced;
  final String? disease;
  final bool hasImage;
  final File? imageFile;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isQuestion = false,
    this.imageUrl,
    this.userId,
    this.isSynced = false,
    this.disease,
    this.hasImage = false,
    this.imageFile,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isQuestion': isQuestion ? 1 : 0,
      'imageUrl': imageUrl,
      'userId': userId,
      'isSynced': isSynced ? 1 : 0,
      'disease': disease,
      'hasImage': hasImage ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'isQuestion': isQuestion,
      'imageUrl': imageUrl,
      'userId': userId,
      'disease': disease,
      'hasImage': hasImage,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      isUser: map['isUser'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isQuestion: map['isQuestion'] == 1,
      imageUrl: map['imageUrl'],
      userId: map['userId'],
      isSynced: map['isSynced'] == 1,
      disease: map['disease'],
      hasImage: map['hasImage'] == 1,
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'],
      isUser: data['isUser'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isQuestion: data['isQuestion'] ?? false,
      imageUrl: data['imageUrl'],
      userId: data['userId'],
      isSynced: true,
      disease: data['disease'],
      hasImage: data['hasImage'] ?? false,
    );
  }
} 