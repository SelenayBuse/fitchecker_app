import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart';
//import 'theme/custom_theme.dart'; // <-- import here

void main() {
  runApp(const FitCheckerApp());
}

class FitCheckerApp extends StatelessWidget {
  const FitCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Flutter95.background,
      home: const FitCheckerHome(),
    );
  }
}

class FitCheckerHome extends StatefulWidget {
  const FitCheckerHome({super.key});

  @override
  State<FitCheckerHome> createState() => _FitCheckerHomeState();
}

class _FitCheckerHomeState extends State<FitCheckerHome> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold95(
      title: 'Flutter95 Counter',
      
      toolbar: Toolbar95(
        actions: [
          Item95(label: 'File', menu: _buildMenu()),
          Item95(label: 'Edit', onTap: (context) {}),
          Item95(label: 'Help', onTap: (context) {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:',
                style: Flutter95.textStyle),
            const SizedBox(height: 8),
            Text('$_counter', style: Flutter95.textStyle),
            const SizedBox(height: 16),
            Button95(
              onTap: _incrementCounter,
              child: const Text('Increment', style: Flutter95.textStyle),
            ),
          ],
        ),
      ),
    );
  }

  Menu95 _buildMenu() {
    return Menu95(
      items: [
        MenuItem95(value: 1, label: 'New'),
        MenuItem95(value: 2, label: 'Open'),
        MenuItem95(value: 3, label: 'Exit'),
      ],
      onItemSelected: (item) {},
    );
  }
}
