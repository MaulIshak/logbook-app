import 'dart:convert'; // Wajib ditambahkan untuk jsonEncode & jsonDecode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/services/mongo_service.dart';
import 'package:my_logbook_app/helper/log_helper.dart';

class LogController {
  final String username;

  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);

  // Kunci unik untuk penyimpanan lokal di Shared Preferences
  static const String _storageKey = 'user_logs_data';

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // --- BARU: KONSTRUKTOR ---
  // Saat Controller dibuat, ia otomatis mencoba mengambil data lama
  LogController(this.username) {
    loadFromDisk(this.username);
  }

  final List<String> categories = [
    'Personal',
    'Work',
    'Study',
    'Health',
    'Travel',
    'Other',
    'All',
  ];

  // 1. Menambah data ke Cloud
  Future<void> addLog(String title, String desc, String category) async {
    final newLog = LogModel(
      id: ObjectId(),
      title: title,
      description: desc,
      date: DateTime.now(),
      username: username,
      category: category,
    );

    try {
      // 2. Kirim ke MongoDB Atlas
      await MongoService().insertLog(newLog);

      // 3. Update UI Lokal (Data sekarang sudah punya ID asli)
      final currentLogs = List<LogModel>.from(logsNotifier.value);
      currentLogs.add(newLog);
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Tambah data dengan ID lokal",
        source: "log_controller.dart",
      );
    } catch (e) {
      await LogHelper.writeLog("ERROR: Gagal sinkronisasi Add - $e", level: 1);
    }
  }

  // void searchLog(String query) {
  //   if (query.isEmpty || query == "") {
  //     logsNotifier.value = logsNotifier.value;
  //   } else {
  //     final filteredLogs = logsNotifier.value.where((log) {
  //       final titleMatch = log.title.toLowerCase().contains(
  //         query.toLowerCase(),
  //       );
  //       final descMatch = log.description.toLowerCase().contains(
  //         query.toLowerCase(),
  //       );
  //       return titleMatch || descMatch;
  //     }).toList();
  //     logsNotifier.value = filteredLogs;
  //   }
  // }

  // 2. Memperbarui data di Cloud (HOTS: Sinkronisasi Terjamin)
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    String category,
  ) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      title: newTitle,
      description: newDesc,
      date: DateTime.now(),
      username: username,
      category: category,
    );

    try {
      // 1. Jalankan update di MongoService (Tunggu konfirmasi Cloud)
      await MongoService().updateLog(updatedLog);

      // 2. Jika sukses, baru perbarui state lokal
      currentLogs[index] = updatedLog;
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Update - $e",
        source: "log_controller.dart",
        level: 1,
      );
      // Data di UI tidak berubah jika proses di Cloud gagal
    }
  }

  // 3. Menghapus data dari Cloud (HOTS: Sinkronisasi Terjamin)```dart
  Future<void> removeLog(LogModel log) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);

    try {
      if (log.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }

      // 1. Hapus data di MongoDB Atlas (Tunggu konfirmasi Cloud)
      await MongoService().deleteLog(log.id!);

      // 2. Jika sukses, baru hapus dari state lokal
      currentLogs.removeWhere((item) => item.id == log.id);
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${log.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Hapus - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // --- BARU: FUNGSI PERSISTENCE (SINKRONISASI JSON) ---

  // Fungsi untuk menyimpan seluruh List ke penyimpanan lokal
  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    // Mengubah List of Object -> List of Map -> String JSON
    final String encodedData = jsonEncode(
      logsNotifier.value.map((log) => log.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  // Ganti pemanggilan SharedPreferences menjadi MongoService
  Future<void> loadFromDisk(String username) async {
    // Mengambil dari Cloud, bukan lokal
    final cloudData = await MongoService().getLogs(username);
    logsNotifier.value = cloudData;
  }
}
