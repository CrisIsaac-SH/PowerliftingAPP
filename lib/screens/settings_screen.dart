import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/weight_unit_controller.dart';
import '../widgets/weight_unit_switch_tile.dart';
import 'app_shell.dart';
import 'athlete_qr_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'meets_screen.dart';
import 'scan_athlete_qr_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isCoach;

  const SettingsScreen({super.key, required this.isCoach});

  Future<void> _signOut(BuildContext context) async {
    final units = context.read<WeightUnitController>();
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    units.reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        leading: const ShellMenuButton(),
        title: const Text('Configurar'),
      ),
      body: ListView(
        children: [
          const WeightUnitSwitchTile(),
          if (isCoach)
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.white),
              title: const Text(
                'Escanear QR de atleta',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScanAthleteQrScreen(),
                  ),
                );
              },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.qr_code_2, color: Colors.white),
              title: const Text(
                'Mi código QR',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AthleteQrScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: Colors.white),
              title: const Text(
                'Competencias',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                final athleteId = Supabase.instance.client.auth.currentUser?.id;
                if (athleteId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeetsScreen(athleteId: athleteId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.military_tech, color: Colors.white),
              title: const Text(
                'Ranking Global',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
