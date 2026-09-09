import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scan_athlete_qr_screen.dart';
import 'login_screen.dart';

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

  // Pantalla de los datos
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

      // cargar atletas asignados
      List<Map<String, dynamic>> listaMisAtletas = [];
      if (assignedIds.isNotEmpty) {
        // CORRECCIÓN AQUÍ: Se cambió la consulta para acceder a exercises(name)
        final misAtletasResponse = await supabase
            .from('profiles')
            .select('id, full_name, weight, gender, workouts(sets(weight, reps, exercises(name)))')
            .inFilter('id', assignedIds);

        for (var perfil in misAtletasResponse) {
          double maxSquat = 0.0;
          double maxBench = 0.0;
          double maxDeadlift = 0.0;

          final workouts = perfil['workouts'] as List<dynamic>? ?? [];
          for (var workout in workouts) {
            final sets = workout['sets'] as List<dynamic>? ?? [];
            for (var setItem in sets) {
              
              final String exercise = (setItem['exercises']?['name'] ?? '').toString().toLowerCase();
              final double weight = (setItem['weight'] ?? 0.0).toDouble();

              if (exercise.contains('squat') || exercise.contains('sentadilla')) {
                if (weight > maxSquat) maxSquat = weight;
              } else if (exercise.contains('bench') || exercise.contains('banca')) {
                if (weight > maxBench) maxBench = weight;
              } else if (exercise.contains('deadlift') || exercise.contains('peso muerto') || exercise.contains('muerto')) {
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

      // cargar atletas que no estan asignados
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

  // funcion de vincular atleta
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

Future<void> _desvincularAtleta(dynamic idBruto, String athleteName) async {

    final String athleteId = idBruto.toString(); 
    

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Desvincular Atleta', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que deseas quitar a $athleteName de tu equipo?', 
                 style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // 3. Eliminar de la base de datos usando .eq() en lugar de .match()
      await Supabase.instance.client
          .from('coach_athletes')
          .delete()
          .eq('coach_id', currentUser.id)
          .eq('athlete_id', athleteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$athleteName ha sido removido de tu equipo'), backgroundColor: Colors.orange),
        );
        // 4. Recargar los datos hace que el atleta desaparezca visualmente
        _cargarDatos(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al desvincular: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // WIDGET DEL MENÚ LATERAL (SIDEBAR) PARA EL COACH
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF180A0A),
              border: Border(bottom: BorderSide(color: Colors.redAccent, width: 2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  radius: 30,
                  child: Icon(Icons.shield, size: 35, color: Colors.white),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Panel',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Modo Coach',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.white),
            title: const Text('Escanear QR Atleta', style: TextStyle(color: Colors.white, fontSize: 16)),
            onTap: () async {
              Navigator.pop(context); // Cierra el Drawer
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScanAthleteQrScreen()),
              );

              if (result == true) {
                _cargarDatos(); // Recarga si se escaneó y vinculó a alguien
              }
            },
          ),
          
          const Spacer(), // Empuja el botón de cerrar sesión hacia abajo
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF333333),
        drawer: _buildDrawer(), // SE AGREGA EL SIDEBAR
        appBar: AppBar(
          title: const Text('PANEL DE COACH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF180A0A),
          foregroundColor: Colors.white, // Esto hace que el ícono de menú hamburguesa sea blanco
          elevation: 0,
          // Se quitaron las "actions" (botones de arriba) para mudarlos al Drawer
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
      clipBehavior: Clip.antiAlias, // Necesario para que el efecto InkWell no se salga de las curvas
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      child: InkWell(
        onTap: () {
          print('Ver detalles de ${atleta['full_name']}');
        },
        splashColor: Colors.redAccent.withOpacity(0.2),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Peso: ${atleta['weight']} kg | Sexo: ${atleta['gender']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón de desvincular
                  IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.white38, size: 20),
                    tooltip: 'Desvincular',
                    onPressed: () => _desvincularAtleta(atleta['id'], atleta['full_name']),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              
              // Totales y Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBadge('SQ', '${atleta['max_squat'].toStringAsFixed(1)} kg'),
                        _buildStatBadge('BP', '${atleta['max_bench'].toStringAsFixed(1)} kg'),
                        _buildStatBadge('DL', '${atleta['max_deadlift'].toStringAsFixed(1)} kg'),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 10),
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
            ],
          ),
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