import 'package:flutter/material.dart';

// AIにコーデを提案してもらう画面(担当: AI提案の実装者が中身を作る)。
// コーデ一覧画面からこのページを開き、1件以上保存したら true を返して pop する
// (一覧側は true なら再読み込みする)。コンストラクタは引数なしのまま変えないこと。
class OutfitSuggestPage extends StatefulWidget {
  const OutfitSuggestPage({super.key});

  @override
  State<OutfitSuggestPage> createState() => _OutfitSuggestPageState();
}

class _OutfitSuggestPageState extends State<OutfitSuggestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AIにコーデを提案してもらう")),
      body: const Center(child: Text("準備中")),
    );
  }
}
