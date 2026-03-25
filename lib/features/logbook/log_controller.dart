import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/services/mongo_service.dart';
import 'package:my_logbook_app/helper/log_helper.dart';

class LogController {
  final String teamId;
  final String username; // username user yang sedang login

  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);

  List<LogModel> _allLogs = [];
  String searchQuery = '';
  String filterCategory = 'All';

  List<LogModel> get logs => logsNotifier.value;

  final _myBox = Hive.box<LogModel>('offline_logs');
  final _pendingDeletesBox = Hive.box<String>('pending_deletes');

  LogController(this.teamId, this.username);

  final List<String> categories = [
    'Personal',
    'Work',
    'Study',
    'Health',
    'Travel',
    'Other',
    'All',
  ];

  // ============================================================
  // CRUD OPERATIONS — Local-first, dengan sync jika online
  // ============================================================

  /// Tambah log. Selalu simpan ke Hive dulu.
  /// Jika [isOnline] = true, langsung upload ke cloud dan tandai synced.
  /// Jika offline, simpan dengan isSynced = false (akan sync nanti).
  Future<void> addLog(
    String title,
    String desc,
    String category,
    String logUsername,
    String logTeamId, {
    bool isOnline = true,
    bool isPublic = false,
  }) async {
    final newLog = LogModel(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now(),
      username: logUsername,
      category: category,
      teamId: logTeamId,
      isSynced: false,
      isPublic: isPublic,
    );

    await _myBox.add(newLog);
    _allLogs.add(newLog);
    _applyFilters();

    if (!isOnline) {
      await LogHelper.writeLog(
        'OFFLINE: Log disimpan lokal (pending sync)',
        source: 'log_controller.dart',
        level: 2,
      );
      return;
    }

    try {
      await MongoService().insertLog(newLog);
      await _updateHiveSyncStatus(newLog.id!, isSynced: true);
      await LogHelper.writeLog(
        "SYNCED: Log '${newLog.title}' berhasil ke cloud",
        source: 'log_controller.dart',
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'OFFLINE: Upload gagal, Log tersimpan lokal — $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  /// Update log. Simpan ke Hive dulu, lalu sync ke cloud jika online.
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    String category,
    String logUsername,
    String logTeamId, {
    bool isOnline = true,
    bool isPublic = false,
  }) async {
    final oldLog = logsNotifier.value[index];

    final updatedLog = LogModel(
      id: oldLog.id,
      title: newTitle,
      description: newDesc,
      date: DateTime.now(),
      username: logUsername,
      category: category,
      teamId: oldLog.teamId,
      isSynced: false,
      isPublic: isPublic,
    );

    // 1. Update di Hive lokal dulu
    final hiveIndex = _myBox.values.toList().indexWhere(
      (l) => l.id == oldLog.id,
    );
    if (hiveIndex != -1) {
      await _myBox.putAt(hiveIndex, updatedLog);
    }

    // 2. Update state in-memory
    final allIndex = _allLogs.indexWhere((l) => l.id == oldLog.id);
    if (allIndex != -1) _allLogs[allIndex] = updatedLog;
    _applyFilters();

    if (!isOnline) {
      await LogHelper.writeLog(
        'OFFLINE: Update disimpan lokal (pending sync)',
        source: 'log_controller.dart',
        level: 2,
      );
      return;
    }

    try {
      await MongoService().updateLog(updatedLog);
      await _updateHiveSyncStatus(updatedLog.id!, isSynced: true);
      await LogHelper.writeLog(
        "SYNCED: Update '${updatedLog.title}' berhasil ke cloud",
        source: 'log_controller.dart',
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'OFFLINE: Update gagal ke cloud, disimpan lokal — $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  /// Hapus log. Jika online, hapus dari cloud dan Hive.
  /// Jika offline, hapus dari Hive dan queue ID ke pending_deletes.
  Future<void> removeLog(LogModel log, {bool isOnline = true}) async {
    if (log.id == null) return;

    // 1. Hapus dari Hive lokal
    final hiveIndex = _myBox.values.toList().indexWhere(
      (l) => l.id == log.id,
    );
    if (hiveIndex != -1) await _myBox.deleteAt(hiveIndex);

    // 2. Hapus dari state in-memory
    _allLogs.removeWhere((item) => item.id == log.id);
    _applyFilters();

    if (!isOnline) {
      // Queue untuk dihapus di cloud nanti (hanya jika sebelumnya sudah di cloud)
      if (log.isSynced) {
        await _pendingDeletesBox.add(log.id!);
      }
      await LogHelper.writeLog(
        'OFFLINE: Hapus disimpan lokal (pending sync)',
        source: 'log_controller.dart',
        level: 2,
      );
      return;
    }

    // 3. Jika online, hapus dari cloud
    try {
      await MongoService().deleteLog(log.id!);
      await LogHelper.writeLog(
        "SYNCED: Hapus '${log.title}' berhasil dari cloud",
        source: 'log_controller.dart',
        level: 2,
      );
    } catch (e) {
      // Cloud gagal — masukkan ke pending deletes untuk dicoba lagi nanti
      await _pendingDeletesBox.add(log.id!);
      await LogHelper.writeLog(
        'OFFLINE: Hapus gagal ke cloud, diqueue — $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  // ============================================================
  // SYNC
  // ============================================================

  /// Sinkronisasi semua data pending ke cloud.
  /// Dipanggil saat koneksi kembali online.
  Future<void> syncPendingData() async {
    int syncedCount = 0;
    int failedCount = 0;

    // 1. Upload semua log yang belum di-sync (isSynced = false)
    final pendingLogs = _myBox.values.where((l) => !l.isSynced).toList();
    for (final log in pendingLogs) {
      try {
        // Cek apakah sudah ada di cloud (update) atau baru (insert)
        // Kita coba insert dulu; jika sudah ada akan gagal (duplicate key)
        await MongoService().insertLog(log);
        await _updateHiveSyncStatus(log.id!, isSynced: true);
        syncedCount++;
      } catch (e) {
        // Mungkin sudah ada di cloud (jika sebelumnya upload sebagian)
        // Coba update sebagai fallback
        try {
          await MongoService().updateLog(log);
          await _updateHiveSyncStatus(log.id!, isSynced: true);
          syncedCount++;
        } catch (_) {
          failedCount++;
        }
      }
    }

    // 2. Proses hapus yang tertunda
    final pendingDeletes = _pendingDeletesBox.values.toList();
    for (final id in pendingDeletes) {
      try {
        await MongoService().deleteLog(id);
      } catch (_) {
        failedCount++;
      }
    }
    if (pendingDeletes.isNotEmpty) await _pendingDeletesBox.clear();

    await LogHelper.writeLog(
      'SYNC: Selesai — $syncedCount berhasil, $failedCount gagal',
      source: 'log_controller.dart',
      level: 2,
    );

    // 3. Refresh in-memory state dari Hive
    loadFromHive();
  }

  /// Berapa banyak data yang belum tersinkronisasi?
  int get pendingSyncCount =>
      _myBox.values.where((l) => !l.isSynced).length +
      _pendingDeletesBox.length;

  // ============================================================
  // FILTER & SEARCH
  // ============================================================

  void searchLog(String query) {
    searchQuery = query;
    _applyFilters();
  }

  void filterLogByCategory(String category) {
    filterCategory = category;
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = _allLogs;
    if (filterCategory != 'All') {
      filtered = filtered.where((l) => l.category == filterCategory).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((log) {
        final titleMatch = log.title.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );
        final descMatch = log.description.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );
        return titleMatch || descMatch;
      }).toList();
    }
    logsNotifier.value = List.from(filtered);
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================

  /// Ambil dari cloud, filter visibilitas, simpan ke Hive
  Future<bool> loadFromDisk(String teamId) async {
    try {
      final allTeamLogs = await MongoService().getLogs(teamId);
      // Filter: tampilkan log sendiri + log public milik sesama tim
      final visibleLogs = allTeamLogs
          .where((log) => log.username == username || log.isPublic)
          .toList();
      _allLogs = visibleLogs;
      _applyFilters();

      // Sinkronisasi semua visible logs ke Hive
      await _syncToHive(visibleLogs);

      await LogHelper.writeLog(
        'CONTROLLER: Fetch ${visibleLogs.length} log dari ${allTeamLogs.length} total tim',
        source: 'log_controller.dart',
        level: 2,
      );
      return true;
    } catch (e) {
      await LogHelper.writeLog(
        'CONTROLLER: loadFromDisk gagal, fallback ke Hive — $e',
        source: 'log_controller.dart',
        level: 1,
      );
      loadFromHive();
      return false;
    }
  }

  /// Simpan semua log ke Hive (menggantikan isi lama)
  Future<void> _syncToHive(List<LogModel> logs) async {
    await _myBox.clear();
    for (final log in logs) {
      await _myBox.add(log);
    }
  }

  /// Load dari Hive lokal (digunakan saat offline)
  void loadFromHive() {
    final localLogs = _myBox.values.toList();
    _allLogs = localLogs;
    _applyFilters();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Update status isSynced sebuah log di Hive berdasarkan ID-nya
  Future<void> _updateHiveSyncStatus(
    String logId, {
    required bool isSynced,
  }) async {
    final hiveList = _myBox.values.toList();
    final index = hiveList.indexWhere((l) => l.id == logId);
    if (index == -1) return;

    final existing = hiveList[index];
    final updated = LogModel(
      id: existing.id,
      title: existing.title,
      description: existing.description,
      date: existing.date,
      username: existing.username,
      category: existing.category,
      teamId: existing.teamId,
      isSynced: isSynced,
    );
    await _myBox.putAt(index, updated);

    // Juga update state in-memory agar UI langsung refresh
    final memIndex = _allLogs.indexWhere((l) => l.id == logId);
    if (memIndex != -1) {
      _allLogs[memIndex] = updated;
      _applyFilters();
    }
  }
}
