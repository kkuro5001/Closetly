import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();


  Future<void> register() async {

    try {

      await Supabase.instance.client.auth.signUp(
        email: emailController.text,
        password: passwordController.text,
      );


      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("登録しました"),
        ),
      );

      Navigator.pop(context);


    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("登録失敗: $e"),
        ),
      );

    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("新規登録"),
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
              onPressed: register,
              child: const Text("登録"),
            ),

          ],
        ),
      ),
    );
  }
}