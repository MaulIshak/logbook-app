import 'package:mongo_dart/mongo_dart.dart';

class LogModel {
  final ObjectId? id; // Penanda unik global dari MongoDB
  final String title;
  final String description;
  final DateTime date;
  final String username;
  final String category;

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.username,
    required this.category,
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id ?? ObjectId(), // Buat ID otomatis jika belum ada
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
      'username': username,
      'category': category,
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['_id'] as ObjectId?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      username: map['username'] ?? '',
      category: map['category'] ?? '',
    );
  }
}
