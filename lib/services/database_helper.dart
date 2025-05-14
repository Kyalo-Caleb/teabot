import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chat_messages.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        isUser INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        isQuestion INTEGER NOT NULL,
        imageUrl TEXT,
        userId TEXT,
        isSynced INTEGER NOT NULL,
        disease TEXT,
        hasImage INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN hasImage INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<String> insertMessage(ChatMessage message) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final messageMap = message.toMap();
    messageMap['id'] = id;
    
    await db.insert(
      'chat_messages',
      messageMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<ChatMessage>> getUnsyncedMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  Future<void> markMessageAsSynced(String id) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ChatMessage>> getMessagesByDisease(String disease) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'disease = ?',
      whereArgs: [disease],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 