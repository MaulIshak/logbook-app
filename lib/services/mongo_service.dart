import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/helper/log_helper.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  final String _source = 'mongo_service.dart';

  Db? _db;

  String get _uri {
    final u = dotenv.env['MONGODB_URI'];
    if (u == null) throw Exception('MONGODB_URI tidak ditemukan di .env');
    return u;
  }

  /// Buka koneksi ke MongoDB (dipanggil sekali saat app start)
  Future<void> connect() async {
    try {
      _db = await Db.create(_uri);
      await _db!.open().timeout(const Duration(seconds: 15));
      await LogHelper.writeLog(
        'DATABASE: Koneksi ke MongoDB berhasil',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Gagal konek — $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// Pastikan koneksi aktif sebelum operasi
  Future<DbCollection> _getCollection(String name) async {
    if (_db == null || !_db!.isConnected) {
      await connect();
    }
    return _db!.collection(name);
  }

  /// READ: Ambil semua log berdasarkan teamId
  Future<List<LogModel>> getLogs(String teamId) async {
    try {
      final col = await _getCollection('logs');
      final docs = await col
          .find(where.eq('teamId', teamId))
          .toList()
          .timeout(const Duration(seconds: 20));

      final logs = docs.map((doc) => LogModel.fromMap(doc)).toList();
      await LogHelper.writeLog(
        'DATABASE: Berhasil ambil ${logs.length} log dari cloud',
        source: _source,
        level: 2,
      );
      return logs;
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: getLogs gagal — $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// CREATE: Tambah log ke cloud
  Future<void> insertLog(LogModel log) async {
    try {
      final col = await _getCollection('logs');
      await col.insertOne(log.toMap()).timeout(const Duration(seconds: 15));
      await LogHelper.writeLog(
        "DATABASE: Insert '${log.title}' berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Insert gagal — $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// UPDATE: Perbarui log di cloud
  Future<void> updateLog(LogModel log) async {
    if (log.id == null) throw Exception('ID Log tidak ditemukan untuk update');
    try {
      final col = await _getCollection('logs');
      final id = ObjectId.fromHexString(log.id!);
      await col
          .replaceOne(where.id(id), log.toMap())
          .timeout(const Duration(seconds: 15));
      await LogHelper.writeLog(
        "DATABASE: Update '${log.title}' berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Update gagal — $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// DELETE: Hapus log dari cloud
  Future<void> deleteLog(String id) async {
    try {
      final col = await _getCollection('logs');
      await col
          .remove(where.id(ObjectId.fromHexString(id)))
          .timeout(const Duration(seconds: 15));
      await LogHelper.writeLog(
        'DATABASE: Hapus ID $id berhasil',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Hapus gagal — $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// Tutup koneksi (dipanggil saat app dispose)
  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      await LogHelper.writeLog(
        'DATABASE: Koneksi ditutup',
        source: _source,
        level: 2,
      );
    }
  }
}
