import 'package:flutter/material.dart';

import '../constants/clothing_options.dart';

// サイズ入力欄(登録画面・編集ダイアログで共通)。
// 表記が服の種類で違うため自由入力にし、よく使うサイズはチップで1タップ入力できるようにする。
// 選択中のチップをもう一度押すと空(未設定)に戻る
class SizeField extends StatelessWidget {

  final TextEditingController controller;
  final String? labelText;

  const SizeField({
    super.key,
    required this.controller,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {

    // 入力内容に合わせてチップの選択状態を更新する
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {

        final current = value.text.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: "例: M、25.5、W30",
                border: labelText == null ? const OutlineInputBorder() : null,
                prefixIcon: labelText == null
                    ? const Icon(Icons.straighten)
                    : null,
                suffixIcon: current.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "クリア",
                        icon: const Icon(Icons.clear),
                        onPressed: controller.clear,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in sizeSuggestions)
                  ChoiceChip(
                    label: Text(option),
                    selected: option == current,
                    onSelected: (_) {
                      controller.text = option == current ? "" : option;
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
