import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/config/api_config.dart';

// 以前はカウンターアプリのテンプレートが全てコメントアウトされており
// main が無くて flutter test が失敗していたため、設定値の確認に置き換えた
void main() {
  test('API_BASE_URLのデフォルトはlocalhost:8080', () {
    expect(ApiConfig.baseUrl, 'http://localhost:8080');
  });
}
