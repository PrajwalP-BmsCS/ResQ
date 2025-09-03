import 'package:flutter/material.dart';

class DummyScreen extends StatelessWidget {
  final String title;
  DummyScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          "$title Module Coming Soon",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
