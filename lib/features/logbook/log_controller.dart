import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  static const String _storageKey = 'user_logs_data';

  final ValueNotifier<List<LogModel>> _logsBufferNotifier = ValueNotifier([]);

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

  void addLog(String title, String desc, String username) {
    final newLog = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      username: username,
    );
    _logsBufferNotifier.value = [..._logsBufferNotifier.value, newLog];
    logsNotifier.value = _logsBufferNotifier.value;
    saveToDisk();
  }

  void updateLog(int index, String title, String desc, String username) {
    final currentLogs = List<LogModel>.from(_logsBufferNotifier.value);
    currentLogs[index] = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      username: username,
    );
    _logsBufferNotifier.value = currentLogs;
    logsNotifier.value = _logsBufferNotifier.value;
    saveToDisk();
  }

  void removeLog(int index) {
    final currentLogs = List<LogModel>.from(_logsBufferNotifier.value);
    currentLogs.removeAt(index);
    _logsBufferNotifier.value = currentLogs;
    logsNotifier.value = _logsBufferNotifier.value;
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
