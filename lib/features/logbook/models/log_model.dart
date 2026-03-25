import 'package:mongo_dart/mongo_dart.dart';
import 'package:hive/hive.dart';

part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id; // Penanda unik global dari MongoDB
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final DateTime date;
  @HiveField(4)
  final String username;
  @HiveField(5)
  final String category;
  @HiveField(6)
  final String teamId;
  @HiveField(7)
  final bool isSynced;
  @HiveField(8)
  final bool isPublic; // true = bisa dilihat sesama tim

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.username,
    required this.category,
    required this.teamId,
    this.isSynced = true,
    this.isPublic = false, // default private
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id != null ? ObjectId.fromHexString(id!) : ObjectId(),
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'username': username,
      'category': category,
      'teamId': teamId,
      'isPublic': isPublic,
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    String? id;
    if (map['_id'] is ObjectId) {
      id = (map['_id'] as ObjectId).oid;
    } else if (map['_id'] is String && (map['_id'] as String).isNotEmpty) {
      id = map['_id'] as String;
    }
    final isPublic = map['isPublic'] == true;

    return LogModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null
          ? DateTime.parse(map['date'].toString())
          : DateTime.now(),
      username: map['username'] ?? 'unknown_user',
      category: map['category'] ?? '',
      teamId: map['teamId'] ?? 'no_team',
      isPublic: isPublic,
    );
  }
}
