import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';
import 'clothing_detail_page.dart';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() =>
      _ClosetPageState();
}

class _ClosetPageState
    extends State<ClosetPage> {

  List<Clothing> clothes = [];
  final storageService = StorageService();
  final clothingService = ClothingService();

  @override
  void initState() {
    super.initState();
    loadClothes();
  }

  Future<void> loadClothes() async {

    final result =
        await clothingService
            .getAllClothing();

    setState(() {
      clothes = result;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("クローゼット"),
      ),

      body: GridView.builder(

        padding:
            const EdgeInsets.all(12),

        itemCount: clothes.length,

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount: 2,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          childAspectRatio: 0.7,
        ),

        itemBuilder: (context, index) {

          final clothing =
              clothes[index];

          return GestureDetector(

            onTap: () {

              Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (context) =>
                      ClothingDetailPage(
                    clothing: clothing,
                  ),
                ),
              );
            },

            child: Card(

              elevation: 3,

              clipBehavior:
                  Clip.antiAlias,

              child: Column(

                children: [

                  Expanded(
                    child: FutureBuilder<String>(
                      future: storageService.getSignedUrl(clothing.imagePath),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Center(
                            child: Icon(Icons.broken_image),
                          );
                        }

                        return Image.network(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Padding(

                    padding:
                        const EdgeInsets.all(
                      8,
                    ),

                    child: Column(

                      children: [

                        // カテゴリ
                        Text(

                          clothing.category,

                          style:
                              const TextStyle(

                            fontWeight:
                                FontWeight.bold,

                            fontSize: 16,
                          ),

                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        // 季節
                        Text(

                          clothing.season,

                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}