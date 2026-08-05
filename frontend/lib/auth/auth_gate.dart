//ログイン状態保持
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/main_page.dart';
import '../pages/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {

    final session =
        Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const MainPage();
    }

    return const LoginPage();
  }
}