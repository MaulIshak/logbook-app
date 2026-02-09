import 'package:flutter/material.dart';
import 'counter_controller.dart';


class CounterView extends StatefulWidget {
  const CounterView({super.key});
  @override
  State<CounterView> createState() => _CounterViewState();
}


class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LogBook: Versi SRP")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Total Hitungan:"),
            Text('${_controller.value}', style: const TextStyle(fontSize: 40)),
            SizedBox(
              width: 250,
              child: Slider(
                value: _controller.step.toDouble(),
                min: 0.0,
                max: 100.0,
                label: _controller.step.round().toString(),
                onChanged: (double newValue) {
                  setState(() {
                    _controller.step = newValue.round();
                  });
                },
              ),
            ),
            Text("Step: ${_controller.step}"),
            Padding(
              padding: EdgeInsetsGeometry.only(top:10),
              child: Text("- Log -", style: TextStyle(color:Colors.blueGrey), textAlign: TextAlign.left,),
              
            ),
            for (String history in _controller.histories.reversed.take(5))
              _counterHistory(history)
          ]
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 10,
        children: [
          FloatingActionButton(
            onPressed: () => setState(() => _controller.decrement()),
            child: const Icon(Icons.remove),
          ),
          FloatingActionButton(
            onPressed: () => setState(() => _controller.reset()),
            child: const Icon(Icons.refresh),
          ),
          FloatingActionButton(
            onPressed: () => setState(() => _controller.increment()),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
    // Helper for history
  Widget _counterHistory(String history){
    Color textColor = Colors.blueGrey;
    String historyDate = history.split('|').first.replaceFirst('T', ' ');
    String historyText = history.split('|').last;

    if (historyText.startsWith("+")){
      textColor = Colors.lightGreen;
    }else if (historyText.startsWith("-")){
      textColor = Colors.red;
    }
    
    return Container(
      margin: EdgeInsetsGeometry.only(top: 10),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: BoxBorder.all(width: .5, color: textColor) 
      ),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
          Text(
            historyDate, 
            style: TextStyle(color: const Color.fromARGB(140, 55, 55, 55))),
          Text(historyText, style: TextStyle(color: textColor),)
        ]
      )
      );
  }
}
