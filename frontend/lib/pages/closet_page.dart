import 'package:flutter/material.dart';

class ClosetPage extends StatelessWidget {
  const ClosetPage({super.key});

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      body: Center(
        child: Text(
          "クローゼット",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}