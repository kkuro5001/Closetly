import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/camera_page.dart';
import '../pages/closet_page.dart';
import '../pages/outfits_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  int currentIndex = 0;

  final pages = [
    const HomePage(),
    const CameraPage(),
    const ClosetPage(),
    const OutfitsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,

        // 4項目以上は fixed にしないとラベルが隠れる
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "ホーム",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: "カメラ",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom),
            label: "クローゼット",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style),
            label: "コーデ",
          ),
        ],
      ),
    );
  }
}