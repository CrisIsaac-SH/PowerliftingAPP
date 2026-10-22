import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        title: const Text('Clasificación', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 10, // Cantidad de usuarios de prueba
        itemBuilder: (context, index) {
          return Card(
            color: const Color(0xFF2C2C2C),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: index < 3 ? Colors.orangeAccent : Colors.grey[700],
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: index < 3 ? Colors.black : Colors.white, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              title: Text(
                'Atleta ${index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                '${(10 - index) * 50} pts',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}