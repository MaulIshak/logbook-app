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

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.username,
    required this.category,
    required this.teamId,
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id != null
          ? ObjectId.fromHexString(id!)
          : ObjectId(), // Buat ID otomatis jika belum ada
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
      'username': username,
      'category': category,
      'teamId': teamId,
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: (map['_id'] as ObjectId?)?.oid,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      username: map['username'] ?? 'unknown_user',
      category: map['category'] ?? '',
      teamId: map['teamId'] ?? 'no_team',
    );
  }
}
