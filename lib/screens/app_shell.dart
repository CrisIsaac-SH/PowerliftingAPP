import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/weight_unit_controller.dart';
import '../widgets/weight_unit_switch_tile.dart';
import 'athlete_qr_screen.dart';
import 'coach_home_screen.dart';
import 'coach_train_screen.dart';
import 'community_forum_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'news_feed_screen.dart';
import 'scan_athlete_qr_screen.dart';
import 'settings_screen.dart';
import 'train_hub_screen.dart';
import 'workout.dart';

class ShellScope extends InheritedWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ShellScope({
    super.key,
    required this.scaffoldKey,
    required super.child,
  });

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static void openDrawer(BuildContext context) {
    maybeOf(context)?.scaffoldKey.currentState?.openDrawer();
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}

class AppShell extends StatefulWidget {
  final bool isCoach;

  const AppShell({super.key, required this.isCoach});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  Future<void> _signOut() async {
    final units = context.read<WeightUnitController>();
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    units.reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _push(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _athleteDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF180A0A),
              border: Border(
                bottom: BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Perfil de Atleta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Colors.white),
            title: const Text(
              'Mi código QR',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _push(const AthleteQrScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined, color: Colors.white),
            title: const Text(
              'Comunidad y Noticias',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _push(const CommunityForumScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.military_tech, color: Colors.white),
            title: const Text(
              'Ranking Global',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _push(const LeaderboardScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.fitness_center, color: Colors.white),
            title: const Text(
              'Mis Entrenamientos',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _push(const WorkoutScreen()),
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONFIGURACIÓN',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const WeightUnitSwitchTile(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _signOut,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _coachDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF180A0A),
              border: Border(
                bottom: BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Modo Coach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.white),
            title: const Text(
              'Escanear QR Atleta',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanAthleteQrScreen(),
                ),
              );
            },
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONFIGURACIÓN',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const WeightUnitSwitchTile(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _signOut,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.isCoach
        ? const [
            CoachHomeScreen(embedded: true),
            CommunityForumScreen(showNewsTab: false),
            CoachTrainScreen(),
            _NewsTab(),
            SettingsScreen(isCoach: true),
          ]
        : const [
            HomeScreen(embedded: true),
            CommunityForumScreen(showNewsTab: false),
            TrainHubScreen(),
            _NewsTab(),
            SettingsScreen(isCoach: false),
          ];

    return ShellScope(
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF333333),
        drawer: widget.isCoach ? _coachDrawer() : _athleteDrawer(),
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF180A0A),
          indicatorColor: Colors.redAccent.withOpacity(0.25),
          selectedIndex: _index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Comunidad',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Entrenar',
            ),
            NavigationDestination(
              icon: Icon(Icons.article_outlined),
              selectedIcon: Icon(Icons.article),
              label: 'Noticias',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Configurar',
            ),
          ],
        ),
      ),
    );
  }
}

class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Abrir menú',
      onPressed: () => ShellScope.openDrawer(context),
    );
  }
}

class _NewsTab extends StatelessWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        leading: const ShellMenuButton(),
        title: const Text('Noticias'),
      ),
      body: const NewsFeedScreen(),
    );
  }
}
