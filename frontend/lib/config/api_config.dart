// Go APIのベースURL
// ビルド時に --dart-define=API_BASE_URL=https://example.com で上書きする
// ブラウザ(Flutter Web)から到達できるアドレスを指定すること
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
