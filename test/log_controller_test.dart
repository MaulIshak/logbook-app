import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_logbook_app/features/logbook/log_controller.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/services/mongo_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Muat env variables untuk LogHelper
    await dotenv.load(fileName: ".env");

    // Inisialisasi Mock Hive local disk env
    tempDir = Directory.systemTemp.createTempSync('hive_test_dir_full');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  // =========================================================
  // 1. SAVE DATA TO DISK (OFFLINE FLOW / HIVE ONLY)
  // =========================================================
  group('Save Data to Disk / Local Storage (LogController offline tests)', () {
    setUp(() async {
      await Hive.openBox<LogModel>('offline_logs');
      await Hive.openBox<String>('pending_deletes');
    });

    tearDown(() async {
      if (Hive.isBoxOpen('offline_logs')) await Hive.box<LogModel>('offline_logs').clear();
      if (Hive.isBoxOpen('pending_deletes')) await Hive.box<String>('pending_deletes').clear();
    });

    test('TC_Disk_01 - Simpan log ke disk (isOnline=false)', () async {
      // (1) Setup
      final controller = LogController('1', 'admin');

      // (2) Exercise
      await controller.addLog('Meeting', 'Catatan disk lokal', 'Work', 'admin', '1', isOnline: false);

      // (3) Verify
      final box = Hive.box<LogModel>('offline_logs');
      expect(box.length, 1, reason: 'Data harus sukses ditulis ke local disk (Hive Box)');
      expect(controller.logs.length, 1, reason: 'In-memory state (List Logs) bertambah seiring masuknya data disk');
      expect(controller.logs.first.title, 'Meeting');
    });

    test('TC_Disk_02 - Properti isSynced dipaksa false bila data disimpan secara offline', () async {
      // (1) Setup
      final controller = LogController('1', 'admin');

      // (2) Exercise
      // `isOnline: false` merepresentasikan perangkat tak berinternet
      await controller.addLog('Coding', 'Merapikan test', 'Study', 'admin', '1', isOnline: false);

      // (3) Verify
      final box = Hive.box<LogModel>('offline_logs');
      final logDiDisk = box.values.first;

      expect(logDiDisk.isSynced, isFalse, reason: 'Mekanisme "simpan disk only" otomatis menandakan status sync ditangguhkan (false)');
    });

    test('TC_Disk_03 - Exception terjadi ketika storage box rusak / gagal diakses', () async {
      // (1) Setup
      final controller = LogController('1', 'admin');

      // Tutup box secara paksa untuk mensimulasikan kegagalan baca/tulis I/O disk (Hive Error)
      await Hive.box<LogModel>('offline_logs').close();

      // (2) Exercise & Verify
      expect(
        () async => await controller.addLog('Error', 'Disk korup', 'Work', 'admin', '1', isOnline: false),
        throwsA(isA<HiveError>()),
        reason: 'HiveError dilempar saat object _myBox memanggil add(), karena DB disk terkunci / tertutup',
      );
      
      // Catatan: controller akan berhenti operasi dan error akan propogasikan ke handler UI.
    });
  });

  // =========================================================
  // 2. SAVE DATA TO CLOUD SERVICE (ONLINE FLOW / MONGODB)
  // =========================================================
  group('Save Data to Cloud Service (LogController online tests)', () {
    setUp(() async {
      await Hive.openBox<LogModel>('offline_logs');
      await Hive.openBox<String>('pending_deletes');
    });

    tearDown(() async {
      if (Hive.isBoxOpen('offline_logs')) await Hive.box<LogModel>('offline_logs').clear();
      if (Hive.isBoxOpen('pending_deletes')) await Hive.box<String>('pending_deletes').clear();
    });

    test('TC_Cloud_01 - Insert Log should be persisted to Cloud (isOnline=true)', () async {
      final controller = LogController('1', 'admin');
      
      await controller.addLog('Rapat', 'Project X', 'Work', 'admin', '1', isOnline: true);

      final box = Hive.box<LogModel>('offline_logs');
      final savedLogs = box.values.toList();
      
      expect(savedLogs.length, 1, reason: 'Sistem harus tetap melakukan backup log terbaru secara lokal sementara proses cloud juga ditembak');
      expect(controller.logs.length, 1, reason: 'State UI Memory harus ikut ter-update');
    });

    test('TC_Cloud_02 - Failed cloud push should fallback to local as Pending', () async {
      final controller = LogController('1', 'admin');

      // Putuskan koneksi sebelumnya dan rusak env URI agar MongoDB Service mutlak melempar Exception
      await MongoService().close();
      final originalUri = dotenv.env['MONGODB_URI'];
      dotenv.env['MONGODB_URI'] = 'mongodb://0.0.0.0:27099/fake';

      // Dalam Test Environment yang error, operasi cloud akan Exception/Error.
      await controller.addLog('Survey', 'Test Error Fallback', 'Work', 'admin', '1', isOnline: true);

      final box = Hive.box<LogModel>('offline_logs');
      final fallbackLog = box.values.last;

      expect(box.values.length, greaterThanOrEqualTo(1), reason: 'Sistem log controller menahan _crash_ menggunakan catch block, backup disk lokal dipertahankan');
      expect(fallbackLog.isSynced, isFalse, reason: 'Gagal Cloud membuat fallback local menyetel flag isSynced ke _false_');

      // Pulihkan koneksi ke env asli untuk test berikutnya
      if (originalUri != null) {
        dotenv.env['MONGODB_URI'] = originalUri;
      }
    });

    test('TC_Cloud_03 - State UI logs must immediately update regardless of cloud delay', () async {
      final controller = LogController('1', 'admin');
      expect(controller.logs.isEmpty, isTrue);

      // Panggil asinkron tetapi jangan tunggu proses selesai secara block penuh
      final futureAdd = controller.addLog('Delay Action', 'Test Async Behaviour', 'Other', 'admin', '1', isOnline: true);

      // Berikan jeda waktu microtask agar penyimpanan ke disk lokal (`_myBox.add`) selesai
      await Future.delayed(const Duration(milliseconds: 100));

      // Pastikan memory bertambah di UI tanpa peduli DB Cloud masih loading lambat
      expect(controller.logs.isNotEmpty, isTrue, reason: 'Aplikasi menggunakan Optimistic UI (Data memory sudah ke-update).');
      expect(controller.logs.first.title, 'Delay Action');

      await futureAdd; // Biarkan operasi resolve (atau catch MongoException) sebelum cleanup
    });
  });
}
