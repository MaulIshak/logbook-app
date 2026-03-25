import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/features/onboarding/onboarding_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  // Tangkap semua error Flutter (UI errors, assertion, dll)
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack.toString());
  };

  // Tangkap semua error Dart async yang tidak tertangkap (termasuk dari isolate)
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");
    await Hive.initFlutter();
    Hive.registerAdapter(LogModelAdapter());
    await Hive.openBox<LogModel>('offline_logs');
    await Hive.openBox<String>('pending_deletes'); // ID log yang dihapus saat offline
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    debugPrint('=== UNHANDLED ASYNC ERROR ===');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: const OnboardingView(),
    );
  }
}

// Aplikasi saya crash ketika masuk ke halaman utama. Crash ketika tampilannya "Menghubungkan ke mongodb atlas". Walau sempat beberapa detik loadingnya berjalan lancar, tapi setelah itu tampilan loadingnya freeze dan aplikasinya crash. Ini kenapa? dan bagaimana memperbaikinya? padahal kalau soal koneksi saya sudah test dan berhasil (menggunakan connection_test.dart)
