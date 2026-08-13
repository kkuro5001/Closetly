import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../services/storage_service.dart';

class ClothingDetailPage extends StatelessWidget {

  final Clothing clothing;
  final storageService = StorageService();

  ClothingDetailPage({
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
              child: FutureBuilder<String>(
                future: storageService.getSignedUrl(clothing.imagePath),
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 350,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox(
                      height: 350,
                      child: Center(
                        child: Icon(Icons.broken_image, size: 64),
                      ),
                    );
                  }

                  return Image.network(
                    snapshot.data!,
                    height: 350,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 350,
                        child: Center(
                          child: Icon(Icons.broken_image, size: 64),
                        ),
                      );
                    },
                  );
                },
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