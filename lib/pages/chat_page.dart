import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:teabot/services/disease_detection_factory.dart';
import 'package:teabot/services/disease_detection_interface.dart';
import 'package:teabot/services/disease_info_service.dart';
import 'package:teabot/services/chat_sync_service.dart';
import 'package:teabot/models/chat_message.dart';

class ChatPage extends StatefulWidget {
  final String? initialDisease;
  final double? initialConfidence;
  final File? imageFile;
  final String? imageUrl;

  const ChatPage({
    Key? key,
    this.initialDisease,
    this.initialConfidence,
    this.imageFile,
    this.imageUrl,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatSyncService _chatSyncService = ChatSyncService();
  bool _hasUploadedImage = false;
  String? _currentImageUrl;
  String _analysisStatus = 'pending';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final bool _isLoading = false;
  String? _errorMessage;
  String? _currentDisease;
  File? _imageFile;
  bool _isProcessing = false;
  double? _confidence;
  late final DiseaseDetectionInterface _diseaseDetectionService;

  final List<String> _predefinedQuestions = [
    "What is the disease?",
    "What is the cause of the disease?",
    "What are the possible curatives?",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _checkForUploadedImage();
    _initializeChat();
    _diseaseDetectionService = DiseaseDetectionFactory.create();
    _currentDisease = widget.initialDisease;
    _confidence = widget.initialConfidence;
    _imageFile = widget.imageFile;
    
    if (_currentDisease != null) {
      _addDefaultQuestions();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _chatSyncService.dispose();
    _diseaseDetectionService.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    debugPrint('\n=== Initializing Chat ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    if (_currentDisease != null) {
      // Load existing messages for this disease
      final messages = await _chatSyncService.loadMessages(_currentDisease!);
      setState(() {
        _messages.addAll(messages);
      });
    } else {
      // Add initial message with image placeholder
      final welcomeMessage = ChatMessage(
        text: 'Welcome! Please select an image of a tea leaf to analyze.',
        isUser: false,
        timestamp: DateTime.now(),
        disease: null,
      );
      await _chatSyncService.saveMessage(welcomeMessage);
      setState(() {
        _messages.add(welcomeMessage);
      });
    }
    
    debugPrint('=== Chat Initialization Completed ===\n');
  }

  void _showDefaultQuestions() {
    final disease = widget.initialDisease?.toLowerCase();
    final questions = [
      'What is ${widget.initialDisease}?',
      'What are the symptoms of ${widget.initialDisease}?',
      'How can I treat ${widget.initialDisease}?',
      'What causes ${widget.initialDisease}?',
    ];

    setState(() {
      _messages.add(ChatMessage(
        text: 'Here are some questions you can ask about ${widget.initialDisease}:',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      for (final question in questions) {
        _messages.add(ChatMessage(
          text: question,
          isUser: false,
          isQuestion: true,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _checkForUploadedImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final latestImage = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .orderBy('uploadedAt', descending: true)
          .limit(1)
          .get();

      if (latestImage.docs.isNotEmpty) {
        final imageData = latestImage.docs.first.data();
        setState(() {
          _hasUploadedImage = true;
          _currentImageUrl = imageData['imageUrl'];
          _analysisStatus = imageData['status'] ?? 'pending';
        });
        _animationController.forward();
        
        // Listen for status updates
        final imageId = latestImage.docs.first.id;
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .doc(imageId)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            setState(() {
              _analysisStatus = snapshot.data()?['status'] ?? 'pending';
            });
          }
        });
      }
    }
  }

  Widget _buildAnalysisStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_analysisStatus) {
      case 'analyzing':
        statusColor = Colors.blue;
        statusIcon = Icons.analytics;
        statusText = 'Analyzing image...';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Analysis complete';
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Analysis failed';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Waiting for analysis';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImageUploadOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isValidImageType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png'].contains(ext);
  }

  Future<bool> _showImagePreview(File imageFile) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Upload'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to upload images')),
        );
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      if (!_isValidImageType(pickedFile.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid image file (JPG, JPEG, or PNG)')),
        );
        return;
      }

      File? imageFile = File(pickedFile.path);
      
      // Compress image
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
        return;
      }
      
      imageFile = File(result.path);
      
      // Show preview and get confirmation
      final shouldUpload = await _showImagePreview(imageFile);
      if (shouldUpload != true) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Create base directory if it doesn't exist
      final storageRef = FirebaseStorage.instance.ref();
      final baseDir = storageRef.child('chat_images/${user.uid}');
      
      // Upload file
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final uploadTask = baseDir.child(fileName).putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${path.extension(imageFile.path).substring(1)}',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Update progress if needed
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .add({
            'imageUrl': downloadUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

      setState(() {
        _hasUploadedImage = true;
        _currentImageUrl = downloadUrl;
        _analysisStatus = 'pending';
      });

      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
    }
  }

  Future<void> _captureImage() async {
    debugPrint('\n=== Starting Image Capture ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('Image captured from camera: ${image.path}');
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showError('Failed to capture image: $e');
    }
    return;
  }

  Future<void> _pickImage() async {
    debugPrint('\n=== Starting Image Selection ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('Image selected from gallery: ${image.path}');
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showError('Failed to pick image: $e');
    }
    return;
  }

  Future<void> _processSelectedImage(File imageFile) async {
    debugPrint('\n=== Processing Selected Image ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Image path: ${imageFile.path}');
    
    setState(() {
      _isProcessing = true;
      _imageFile = imageFile;
    });

    try {
      // Add user's image message
      _messages.add(ChatMessage(
        text: 'Processing image...',
        isUser: true,
        timestamp: DateTime.now(),
        hasImage: true,
        imageFile: imageFile,
      ));
      setState(() {});

      // Detect disease
      final result = await _diseaseDetectionService.detectDisease(
        imageFile: imageFile,
      );

      debugPrint('Disease detection result: $result');
      
      setState(() {
        _currentDisease = result['disease'];
        _confidence = result['confidence'];
        _isProcessing = false;
      });

      // Add detection result message
      final detectionMessage = ChatMessage(
        text: 'Disease detected: $_currentDisease (${(_confidence! * 100).toStringAsFixed(1)}% confidence)',
        isUser: false,
        timestamp: DateTime.now(),
        disease: _currentDisease,
      );

      setState(() {
        _messages.add(detectionMessage);
      });
      await _chatSyncService.saveMessage(detectionMessage);

      // Ensure currentDisease is set before adding questions
      if (_currentDisease != null) {
        debugPrint('Adding default questions for disease: $_currentDisease');
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay for better UX
        _addDefaultQuestions();
      } else {
        debugPrint('Error: Disease is null after detection');
      }
      
      setState(() {});
      debugPrint('=== Image Processing Completed ===\n');
    } catch (e) {
      debugPrint('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process image: $e');
    }
    return;
  }

  void _addDefaultQuestions() {
    debugPrint('\n=== Adding Default Questions ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Current Disease: $_currentDisease');
    
    if (_currentDisease == null) {
      debugPrint('Error: Current disease is null');
      return;
    }

    final questions = [
      QuestionCategory(
        title: 'About the Disease',
        questions: [
          'What is $_currentDisease?',
          'What are the symptoms of $_currentDisease?',
          'How severe is $_currentDisease?',
        ],
      ),
      QuestionCategory(
        title: 'Treatment & Prevention',
        questions: [
          'How can I treat $_currentDisease?',
          'What are the best practices to prevent $_currentDisease?',
          'Are there any natural remedies for $_currentDisease?',
        ],
      ),
      QuestionCategory(
        title: 'Impact & Management',
        questions: [
          'How does $_currentDisease affect tea production?',
          'What is the economic impact of $_currentDisease?',
          'How long does it take to control $_currentDisease?',
        ],
      ),
    ];

    debugPrint('Created ${questions.length} question categories');
    _addCategoryMessages(questions);
  }

  Future<void> _addCategoryMessages(List<QuestionCategory> categories) async {
    debugPrint('\n=== Adding Category Messages ===');
    debugPrint('Number of categories: ${categories.length}');

    final introMessage = ChatMessage(
      text: 'Here are some questions you can ask about $_currentDisease:',
      isUser: false,
      timestamp: DateTime.now(),
      disease: _currentDisease,
    );

    debugPrint('Adding intro message');
    setState(() {
      _messages.add(introMessage);
    });
    await _chatSyncService.saveMessage(introMessage);

    for (final category in categories) {
      debugPrint('\nProcessing category: ${category.title}');
      final categoryMessage = ChatMessage(
        text: category.title,
        isUser: false,
        timestamp: DateTime.now(),
        disease: _currentDisease,
      );

      setState(() {
        _messages.add(categoryMessage);
      });
      await _chatSyncService.saveMessage(categoryMessage);

      debugPrint('Adding ${category.questions.length} questions for category ${category.title}');
      for (final question in category.questions) {
        final questionMessage = ChatMessage(
          text: question,
          isUser: false,
          timestamp: DateTime.now(),
          isQuestion: true,
          disease: _currentDisease,
        );

        setState(() {
          _messages.add(questionMessage);
        });
        await _chatSyncService.saveMessage(questionMessage);
      }
    }
    debugPrint('=== Finished Adding Category Messages ===\n');
    
    // Ensure messages are visible by scrolling to bottom
    _scrollToBottom();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Disease Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _captureImage,
            tooltip: 'Capture Image',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickImage,
            tooltip: 'Pick Image',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/placeholder_leaf.jpg',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Select an image to analyze',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
            ),
            // Input area
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type your question...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: _handleSubmitted,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _handleSubmitted(_messageController.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      disease: _currentDisease,
    );

    setState(() {
      _messages.add(userMessage);
    });

    // Save user message
    await _chatSyncService.saveMessage(userMessage);

    _messageController.clear();
    _scrollToBottom();

    // Get response from DiseaseInfoService
    if (_currentDisease != null) {
      debugPrint('Asking question about disease: $_currentDisease');
      final response = DiseaseInfoService.getAnswer(_currentDisease!.toLowerCase(), text);
      
      final botMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        disease: _currentDisease,
      );

      setState(() {
        _messages.add(botMessage);
      });

      // Save bot message
      await _chatSyncService.saveMessage(botMessage);
      
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) 
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.green[800],
                child: const Icon(Icons.eco, color: Colors.white),
              ),
            ),
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: message.isQuestion ? () => _handleSubmitted(message.text) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: message.isQuestion 
                        ? Colors.lightBlue[50] 
                        : message.isUser 
                            ? Colors.green[100] 
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: message.isQuestion
                        ? Border.all(color: Colors.lightBlue[300]!, width: 1)
                        : null,
                    boxShadow: message.isQuestion ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (message.hasImage && message.imageFile != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            message.imageFile!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (message.hasImage && message.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            message.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (message.text.isNotEmpty)
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.isQuestion ? Colors.blue[700] : Colors.black87,
                            fontWeight: message.isQuestion ? FontWeight.w500 : null,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (message.isQuestion)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, size: 14, color: Colors.blue[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to ask',
                                style: TextStyle(
                                  color: Colors.blue[400],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (message.isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.green[800],
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class QuestionCategory {
  final String title;
  final List<String> questions;

  QuestionCategory({
    required this.title,
    required this.questions,
  });
}