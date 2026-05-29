import 'dart:io';

import 'package:flutter/material.dart';

import '../models/clothing.dart';

class ClothingDetailPage extends StatelessWidget {

  final Clothing clothing;

  const ClothingDetailPage({
    super.key,
    required this.clothing,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("服の詳細"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Center(
              child: Image.file(
                File(clothing.imagePath),
                height: 350,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "カテゴリ: ${clothing.category}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "色: ${clothing.color}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "季節: ${clothing.season}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}