class CounterController {
  int _counter = 0; // _ for private
  int step = 1;

  int get value => _counter; // getter

  final List<String> histories = [];

  void increment() {
    if(step == 0) return;
    _counter += step;
    histories.add('${_formatDate(DateTime.now().toIso8601String())}|+$step, count: $_counter');
    removeTrash();
  }

  void decrement() {
    if(step == 0) return;
    _counter -= step;
    histories.add('${_formatDate(DateTime.now().toIso8601String())}|-$step, count: $_counter');
    removeTrash();
  }

  void reset(){
    if (_counter != 0) {
      _counter = 0;
      histories.add('${_formatDate  (DateTime.now().toIso8601String())}|reset');
      removeTrash();
    }
  }

  String _formatDate(String dateTime){
    return dateTime.split(".").first;
  }

  void removeTrash(){
    if (histories.length > 5){
      histories.removeAt(0);
    }
  }
}
