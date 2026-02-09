class CounterController {
  int _counter = 0; // Private

  int get value => _counter; // Getter 
  int step = 1;
  List<String> histories = [];

  void increment() {
    _counter += step;
    histories.add('+$_counter');
  }
  void decrement() { 
    if (_counter > 0) _counter-=step;
    histories.add('-$_counter'); 
    
  }
  void reset() {
    _counter = 0;
    histories.add('reset');
  }
}
