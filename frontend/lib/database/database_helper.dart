//保存用のDBを作成する
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/clothing.dart';

class DatabaseHelper {

  static final DatabaseHelper instance =
      DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('closetly.db');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {

    //DB保存場所 スマホ内のDB保存フォルダ
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(
    Database db,
    int version,
  ) async {

    await db.execute('''
      CREATE TABLE clothes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        category TEXT NOT NULL,
        color TEXT NOT NULL,
        season TEXT NOT NULL
      )
    ''');
  }

   //服を保存
  Future<int> insertClothing(
    Clothing clothing,
  ) async {

    final db = await instance.database;

    return await db.insert(
      'clothes',
      clothing.toMap(),
    );
  }
}