import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_page.dart';
import 'home_page.dart';
import '../navigation/main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {

    try {

      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainPage(),
        ),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "ログイン失敗: $e",
          ),
        ),
      );

    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("ログイン"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "メールアドレス",
              ),
            ),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "パスワード",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: login,
              child: const Text("ログイン"),
            ),

            TextButton(
            onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RegisterPage(),
                ),
                );
            },
            child: const Text("新規登録はこちら"),
            ),

          ],
        ),
      ),
    );
  }
}