import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
//importaciones de pantallas

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _misAtletas = [];
  List<Map<String, dynamic>> _atletasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
//pantalla de los datos
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      // datos del atleta al coach asignado
      final relaciones = await supabase
          .from('coach_athletes')
          .select('athlete_id')
          .eq('coach_id', currentUser.id);

      final List<String> assignedIds = relaciones.map((r) => r['athlete_id'].toString()).toList();

      // cargar ateltas asignados
      List<Map<String, dynamic>> listaMisAtletas = [];
      if (assignedIds.isNotEmpty) {
        final misAtletasResponse = await supabase
            .from('profiles')
            .select('id, full_name, weight, gender, workouts(sets(exercise_name, weight, reps))')
            .inFilter('id', assignedIds);

        for (var perfil in misAtletasResponse) {
          double maxSquat = 0.0;
          double maxBench = 0.0;
          double maxDeadlift = 0.0;

          final workouts = perfil['workouts'] as List<dynamic>? ?? [];
          print('Entrenamientos de ${perfil['full_name']}: $workouts');
          for (var workout in workouts) {
            final sets = workout['sets'] as List<dynamic>? ?? [];
            for (var setItem in sets) {
              final String exercise = (setItem['exercise_name'] ?? '').toString().toLowerCase();
              final double weight = (setItem['weight'] ?? 0.0).toDouble();

              if (exercise.contains('squat') || exercise.contains('sentadilla')) {
                if (weight > maxSquat) maxSquat = weight;
              } else if (exercise.contains('bench') || exercise.contains('banca')) {
                if (weight > maxBench) maxBench = weight;
              } else if (exercise.contains('deadlift') || exercise.contains('peso muerto')) {
                if (weight > maxDeadlift) maxDeadlift = weight;
              }
            }
          }

          listaMisAtletas.add({
            'id': perfil['id'],
            'full_name': perfil['full_name'] ?? 'Atleta sin nombre',
            'weight': perfil['weight']?.toDouble() ?? 0.0,
            'gender': perfil['gender'] ?? '-',
            'max_squat': maxSquat,
            'max_bench': maxBench,
            'max_deadlift': maxDeadlift,
            'total': maxSquat + maxBench + maxDeadlift,
          });
        }
      }

      //cargar atletas que no estan asignados
      final todosLosAtletasResponse = await supabase
          .from('profiles')
          .select('id, full_name, weight, gender')
          .or('is_coach.eq.false,is_coach.is.null');

      final List<Map<String, dynamic>> listaDisponibles = todosLosAtletasResponse
          .map((e) => e as Map<String, dynamic>)
          .where((atleta) => !assignedIds.contains(atleta['id'].toString()))
          .toList();

      setState(() {
        _misAtletas = listaMisAtletas;
        _atletasDisponibles = listaDisponibles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _isLoading = false);
      }
    }
  }
//funcion de vincukar atleta
  Future<void> _vincularAtleta(String athleteId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client.from('coach_athletes').insert({
        'coach_id': currentUser.id,
        'athlete_id': athleteId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Atleta agregado a tu equipo!'), backgroundColor: Colors.green),
        );
        // Recargamos los datos para que el atleta se mueva de pestaña
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF333333),
        appBar: AppBar(
          title: const Text('PANEL DE COACH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF180A0A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Cerrar Sesión',
              onPressed: _cerrarSesion,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.group), text: 'MIS ATLETAS'),
              Tab(icon: Icon(Icons.person_add), text: 'DISPONIBLES'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : TabBarView(
                children: [
                  // PESTAÑA 1: MIS ATLETAS
                  RefreshIndicator(
                    onRefresh: _cargarDatos,
                    color: Colors.redAccent,
                    backgroundColor: const Color(0xFF2C2C2C),
                    child: _misAtletas.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'Aún no tienes atletas en tu equipo.\nVe a "Disponibles" para agregar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54, fontSize: 16),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _misAtletas.length,
                            itemBuilder: (context, index) {
                              return _buildMiAtletaCard(_misAtletas[index]);
                            },
                          ),
                  ),

                  // PESTAÑA 2: ATLETAS DISPONIBLES
                  RefreshIndicator(
                    onRefresh: _cargarDatos,
                    color: Colors.redAccent,
                    backgroundColor: const Color(0xFF2C2C2C),
                    child: _atletasDisponibles.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'No hay más atletas disponibles.',
                                  style: TextStyle(color: Colors.white54, fontSize: 16),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _atletasDisponibles.length,
                            itemBuilder: (context, index) {
                              return _buildAtletaDisponibleCard(_atletasDisponibles[index]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // Tarjeta para los atletas que YA SON del Coach
  Widget _buildMiAtletaCard(Map<String, dynamic> atleta) {
    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 76, 1, 1),
                  radius: 22,
                  child: Icon(Icons.person, color: Colors.redAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        atleta['full_name'],
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Peso: ${atleta['weight']} kg | Sexo: ${atleta['gender']}',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF180A0A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text('TOTAL', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(
                        '${atleta['total'].toStringAsFixed(0)} kg',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('SQ', '${atleta['max_squat'].toStringAsFixed(1)} kg'),
                _buildStatBadge('BP', '${atleta['max_bench'].toStringAsFixed(1)} kg'),
                _buildStatBadge('DL', '${atleta['max_deadlift'].toStringAsFixed(1)} kg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta para los atletas disponibles (con botón de agregar)
  Widget _buildAtletaDisponibleCard(Map<String, dynamic> atleta) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Colors.white12,
          child: Icon(Icons.person_outline, color: Colors.white54),
        ),
        title: Text(
          atleta['full_name'] ?? 'Sin nombre',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Peso: ${atleta['weight']?.toString() ?? '--'} kg',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _vincularAtleta(atleta['id']),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text('Agregar', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 76, 1, 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}