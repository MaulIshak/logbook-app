class CounterController {
  int _counter = 0; // _ for private
  int step = 1;

  int get value => _counter; // getter

  final List<String> histories = [];

  void increment() {
    _counter += step;
    histories.add('${_formatDate(DateTime.now().toIso8601String())}|+$step, count: $_counter');
  }

  void decrement() {
    _counter -= step;
    histories.add('${_formatDate(DateTime.now().toIso8601String())}|-$step, count: $_counter');
  }

  void reset() {
    _counter = 0;
    histories.add('${_formatDate  (DateTime.now().toIso8601String())}|reset');
  }

  String _formatDate(String dateTime){
    return dateTime.split(".").first;
  }
}
