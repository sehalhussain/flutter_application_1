import 'package:flutter/material.dart';
import '../models/name_model.dart';

class AsmaDetailScreen extends StatelessWidget {
  final AsmaName name;

  const AsmaDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(name.transliteration,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF064E3B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section for the specific name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                ),
              ),
              child: Column(
                children: [
                  Text(name.name,
                      style:
                          const TextStyle(fontSize: 80, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(name.transliteration,
                      style: const TextStyle(
                          fontSize: 24, color: Color(0xFFA7F3D0))),
                ],
              ),
            ),

            // Meaning & Description Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("MEANING",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(name.meaning,
                      style: const TextStyle(fontSize: 18, height: 1.5)),
                  const SizedBox(height: 30),

                  // Add more details here like Benefits, Quranic References, etc.
                  const Text("RECITATION BENEFITS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                    "Regular recitation of this Name brings peace of mind and clarity of heart.",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
