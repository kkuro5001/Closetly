import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/clothing.dart';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() =>
      _ClosetPageState();
}

class _ClosetPageState
    extends State<ClosetPage> {

  List<Clothing> clothes = [];

  @override
  void initState() {
    super.initState();
    loadClothes();
  }

  Future<void> loadClothes() async {

    final result =
        await DatabaseHelper.instance
            .getAllClothing();

    setState(() {
      clothes = result;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("クローゼット"),
      ),

      body: GridView.builder(

        padding:
            const EdgeInsets.all(12),

        itemCount: clothes.length,

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount: 2,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          childAspectRatio: 0.7,
        ),

        itemBuilder: (context, index) {

          final clothing =
              clothes[index];

          return Card(

            child: Column(

              children: [

                Expanded(

                  child: Image.file(
                    File(
                      clothing.imagePath,
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.all(8),

                  child: Column(

                    children: [
                      //カテゴリー
                      Text(
                        clothing.category,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      //季節
                      Text(
                        clothing.season,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}