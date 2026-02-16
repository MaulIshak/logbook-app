import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  int _counter = 0; // _ for private
  int step = 1;

  int get value => _counter; // getter

  List<String> histories = [];

  Future<void> init() async {
    _counter = await loadLastValue();
    histories = await loadHistories();
  }

  Future<void> increment() async {
    if (step == 0) return;
    _counter += step;
    histories.add(
      '${_formatDate(DateTime.now().toIso8601String())}|+$step, count: $_counter',
    );
    removeTrash();
    await saveAll();
  }

  Future<void> decrement() async {
    if (step == 0) return;
    _counter -= step;
    histories.add(
      '${_formatDate(DateTime.now().toIso8601String())}|-$step, count: $_counter',
    );
    removeTrash();
    await saveAll();
  }

  Future<void> reset() async {
    if (_counter != 0) {
      _counter = 0;
      histories.add('${_formatDate(DateTime.now().toIso8601String())}|reset');
      removeTrash();
      await saveAll();
    }
  }

  String _formatDate(String dateTime) {
    return dateTime.split(".").first;
  }

  void removeTrash() {
    if (histories.length > 5) {
      histories.removeAt(0);
    }
  }

  // Data Saving
  // Fungsi untuk menyimpan angka terakhir
  Future<void> saveLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_counter', _counter);
    // 'last_counter' adalah Kunci (Key) untuk memanggil data nanti
  }

  Future<int> loadLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    // Ambil nilai berdasarkan Key, jika kosong (null) berikan nilai default 0
    return prefs.getInt('last_counter') ?? 0;
  }

  Future<void> saveHistories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('histories', histories);
  }

  Future<List<String>> loadHistories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('histories') ?? [];
  }

  Future<void> saveAll() async {
    await saveLastValue();
    await saveHistories();
  }
}
