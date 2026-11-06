import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/size_field.dart';

void main() {
  testWidgets('チップで入力・同じチップで解除でき、ダイアログ内でも表示できる', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [SizeField(controller: controller, labelText: 'サイズ(任意)')],
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(ChoiceChip, 'M'));
    await tester.pump();
    expect(controller.text, 'M');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'M')).selected, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'M'));
    await tester.pump();
    expect(controller.text, '');

    await tester.enterText(find.byType(TextField), '25.5');
    await tester.pump();
    expect(controller.text, '25.5');
    expect(tester.takeException(), isNull);
  });
}
