import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'database_helper.dart';

class ChatSyncService {
  static final ChatSyncService _instance = ChatSyncService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;

  factory ChatSyncService() => _instance;

  ChatSyncService._internal() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = results.contains(ConnectivityResult.wifi) || 
                          results.contains(ConnectivityResult.mobile) ||
                          results.contains(ConnectivityResult.ethernet);
      if (hasConnection) {
        await syncMessages();
      }
    });

    // Start periodic sync every 5 minutes when online
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      if (hasConnection) {
        await syncMessages();
      }
    });
  }

  Future<void> saveMessage(ChatMessage message) async {
    // Save to local database
    final messageId = await _dbHelper.insertMessage(message);

    // Try to sync immediately if online
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      syncMessages();
    }
  }

  Future<void> syncMessages() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _isSyncing = false;
        return;
      }

      // Get all unsynced messages
      final unsyncedMessages = await _dbHelper.getUnsyncedMessages();
      
      for (var message in unsyncedMessages) {
        try {
          // Add message to Firestore
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('chat_messages')
              .add(message.toFirestore());

          // Mark message as synced in local database
          await _dbHelper.markMessageAsSynced(message.id!);
        } catch (e) {
          print('Error syncing message ${message.id}: $e');
          // Continue with next message even if one fails
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<List<ChatMessage>> loadMessages(String disease) async {
    return _dbHelper.getMessagesByDisease(disease);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
} 