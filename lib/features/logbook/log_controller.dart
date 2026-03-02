import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  static const String _storageKey = 'user_logs_data';
  final ValueNotifier<List<LogModel>> _logsBufferNotifier = ValueNotifier([]);
  String _activeCategory = 'All'; // Track filter kategori yang sedang aktif
  final List<String> categories = [
    'Personal',
    'Work',
    'Study',
    'Health',
    'Travel',
    'Other',
    'All',
  ];

  LogController(String username) {
    loadFromDisk(username);
  }

  void searchLog(String query) {
    if (query.isEmpty || query == "") {
      logsNotifier.value = _logsBufferNotifier.value;
    } else {
      final filteredLogs = _logsBufferNotifier.value.where((log) {
        final titleMatch = log.title.toLowerCase().contains(
          query.toLowerCase(),
        );
        final descMatch = log.description.toLowerCase().contains(
          query.toLowerCase(),
        );
        return titleMatch || descMatch;
      }).toList();
      logsNotifier.value = filteredLogs;
    }
  }

  void filterLog(String category) {
    _activeCategory = category; // Simpan filter aktif
    if (category.isEmpty || category == "All") {
      logsNotifier.value = _logsBufferNotifier.value;
    } else {
      final filteredLogs = _logsBufferNotifier.value.where((log) {
        final categoryMatch = log.category.toLowerCase().contains(
          category.toLowerCase(),
        );
        return categoryMatch;
      }).toList();
      logsNotifier.value = filteredLogs;
    }
  }

  void addLog(String title, String desc, String username, String category) {
    final newLog = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      username: username,
      category: category,
    );
    _logsBufferNotifier.value = [..._logsBufferNotifier.value, newLog];
    logsNotifier.value = _logsBufferNotifier.value;
    saveToDisk();
  }

  void updateLog(
    int index,
    String title,
    String desc,
    String username,
    String category,
  ) {
    final currentLogs = List<LogModel>.from(_logsBufferNotifier.value);
    currentLogs[index] = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      username: username,
      category: category,
    );
    _logsBufferNotifier.value = currentLogs;
    logsNotifier.value = _logsBufferNotifier.value;
    saveToDisk();
  }

  void removeLog(LogModel logToRemove) {
    // Hapus berdasarkan referensi object, bukan index,
    // agar tidak salah hapus saat ada filter aktif
    final currentLogs = List<LogModel>.from(_logsBufferNotifier.value);
    currentLogs.remove(logToRemove);
    _logsBufferNotifier.value = currentLogs;
    // Re-apply filter yang sedang aktif setelah menghapus
    filterLog(_activeCategory);
    saveToDisk();
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      _logsBufferNotifier.value.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      _logsBufferNotifier.value = decoded
          .map((e) => LogModel.fromMap(e))
          .where((e) => e.username == username)
          .toList();
      logsNotifier.value = _logsBufferNotifier.value;
    }
  }
}
