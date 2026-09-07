import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';

class ClothingDetailPage extends StatefulWidget {

  final Clothing clothing;

  const ClothingDetailPage({
    super.key,
    required this.clothing,
  });

  @override
  State<ClothingDetailPage> createState() => _ClothingDetailPageState();
}

class _ClothingDetailPageState extends State<ClothingDetailPage> {

  final storageService = StorageService();
  final clothingService = ClothingService();

  bool isDeleting = false;

  String _formatDate(DateTime date) {
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _confirmAndDelete() async {

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("服を削除"),
        content: const Text("この服を削除しますか？この操作は取り消せません。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("削除"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {

      await clothingService.deleteClothing(widget.clothing.id!);
      await storageService.deleteImage(widget.clothing.imagePath);

      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {

      if (mounted) {
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("削除に失敗しました: $e"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final clothing = widget.clothing;

    return Scaffold(

      appBar: AppBar(
        title: const Text("服の詳細"),
        actions: [
          IconButton(
            onPressed: isDeleting ? null : _confirmAndDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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

            if (clothing.createdAt != null) ...[
              const SizedBox(height: 10),

              Text(
                "保存日: ${_formatDate(clothing.createdAt!)}",
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
