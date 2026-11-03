import 'package:flutter/material.dart';

import '../services/storage_service.dart';

// 服の画像を署名付きURLで表示する小さな部品(コーデ画面などで共通して使う)。
// バケットが非公開なので、表示のたびに署名付きURLを取り直す。
class ClothingThumbnail extends StatefulWidget {

  final String imagePath;
  final double? width;
  final double? height;

  const ClothingThumbnail({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
  });

  @override
  State<ClothingThumbnail> createState() => _ClothingThumbnailState();
}

class _ClothingThumbnailState extends State<ClothingThumbnail> {

  // build のたびに URL を取り直さないよう、Future を保持する
  late Future<String> _url = StorageService().getSignedUrl(widget.imagePath);

  @override
  void didUpdateWidget(covariant ClothingThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _url = StorageService().getSignedUrl(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<String>(
        future: _url,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Icon(Icons.broken_image));
          }
          return Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            width: widget.width,
            height: widget.height,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Icon(Icons.broken_image));
            },
          );
        },
      ),
    );
  }
}
