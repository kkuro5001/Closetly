import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {

    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "ホーム",
              style: TextStyle(fontSize: 24),
            ),

            const SizedBox(height: 20),

            Text(
              user == null
                  ? "Supabase接続済み（未ログイン）"
                  : "ログインユーザー: ${user.id}",
            ),

          ],
        ),
      ),
    );
  }
}