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

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadClothes();
  }

  Future<void> loadClothes() async {

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {

      final result = await clothingService.getAllClothing();

      setState(() {
        clothes = result;
        isLoading = false;
      });

    } catch (e, stackTrace) {

      debugPrint("===== クローゼット取得エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("クローゼット"),
        actions: [
          IconButton(
            onPressed: loadClothes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text("服の取得に失敗しました\n$errorMessage", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loadClothes,
                child: const Text("再読み込み"),
              ),
            ],
          ),
        ),
      );
    }

    if (clothes.isEmpty) {
      return const Center(
        child: Text("まだ服が登録されていません"),
      );
    }

    return RefreshIndicator(
      onRefresh: loadClothes,
      child: GridView.builder(

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