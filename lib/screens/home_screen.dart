import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'record_set_screen.dart';
import 'athlete_qr_screen.dart';
import '../utils/one_rep_max.dart';
import 'workout_detail_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. LLAVE PARA CONTROLAR EL MENÚ LATERAL (DRAWER)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _nombre = '';
  bool _isLoading = true;
  
  bool _isLoadingHistory = true;
  List<dynamic> _historialGeneral = [];

  double _maxSquat = 0.0;
  double _maxBench = 0.0;
  double _maxDeadlift = 0.0;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await _obtenerDatosDelUsuario();
    _cargarMarcasPersonales();
    _obtenerHistorialGeneral();
  }

  Future<void> _obtenerDatosDelUsuario() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('full_name, is_coach')
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _nombre = data['full_name'] ?? 'Atleta';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos del usuario: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarMarcasPersonales() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('workouts')
          .select('id, sets(weight, reps, exercises(name))')
          .eq('user_id', user.id);

      double maxSq = 0;
      double maxBp = 0;
      double maxDl = 0;

      for (var workout in response) {
        final sets = workout['sets'] as List<dynamic>? ?? [];
        for (var s in sets) {
          final exerciseName = (s['exercises']?['name'] ?? '').toString().toLowerCase();
          final weight = double.tryParse(s['weight'].toString()) ?? 0.0;
          final reps = int.tryParse(s['reps'].toString()) ?? 0;
          
          final rmCalculado = PowerliftingUtils.calcular1RM(weight, reps);

          if (exerciseName.contains('squat') || exerciseName.contains('sentadilla')) {
            if (rmCalculado > maxSq) maxSq = rmCalculado;
          } else if (exerciseName.contains('bench') || exerciseName.contains('banca')) {
            if (rmCalculado > maxBp) maxBp = rmCalculado;
          } else if (exerciseName.contains('deadlift') || exerciseName.contains('muerto')) {
            if (rmCalculado > maxDl) maxDl = rmCalculado;
          }
        }
      }

      if (mounted) {
        setState(() {
          _maxSquat = maxSq;
          _maxBench = maxBp;
          _maxDeadlift = maxDl;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar marcas personales: $e');
    }
  }

  Future<void> _obtenerHistorialGeneral() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('sets')
            .select('workout_id, weight, reps, rpe, exercises(name), workouts!inner(user_id, date)')
            .eq('workouts.user_id', user.id)
            .order('created_at', ascending: false)
            .limit(10);

        if (mounted) {
          setState(() {
            _historialGeneral = data;
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar historial general: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Widget _buildExerciseCard(String title, String imagePath, double maxWeight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordSetScreen(initialExercise: title),
              ),
            );
            _obtenerHistorialGeneral();
            _cargarMarcasPersonales();
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151010),
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: AssetImage(imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1RM: ${maxWeight.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_outline, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2. WIDGET DEL MENÚ LATERAL (SIDEBAR)
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF180A0A),
              border: Border(bottom: BorderSide(color: Colors.redAccent, width: 2)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  radius: 30,
                  child: Icon(Icons.person, size: 35, color: Colors.white),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _nombre,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Perfil de Atleta',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Colors.white),
            title: const Text('Mi código QR', style: TextStyle(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context); // Cierra el Drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AthleteQrScreen()),
              );
            },
          ),
          // Aquí puedes agregar más opciones en el futuro (Ajustes, Calculadora RM, etc.)
          
          const Spacer(), // Empuja el botón de cerrar sesión hacia abajo
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20), // Margen inferior
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF333333);
    const darkAccentColor = Color(0xFF180A0A);
    final double total = _maxSquat + _maxBench + _maxDeadlift;

    return Scaffold(
      key: _scaffoldKey, // 3. ASIGNAMOS LA LLAVE AL SCAFFOLD
      backgroundColor: backgroundColor,
      drawer: _buildDrawer(), // 4. AGREGAMOS EL DRAWER
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    ClipPath(
                      clipper: HeaderClipper(),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        color: darkAccentColor,
                        padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
                        child: Text(
                          'Bienvenido,\n"$_nombre"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // 5. NUEVO BOTÓN DE MENÚ (HAMBURGUESA)
                    Positioned(
                      top: 40,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                        tooltip: 'Abrir menú',
                        onPressed: () {
                          // Abre el menú lateral
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2), // Un toque de rojo
                        ),
                        child: Text(
                          'Total SBD: ${total.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                Expanded(
                  flex: 3, 
                  child: RefreshIndicator(
                    onRefresh: _inicializarDatos,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildExerciseCard('SQUAT', 'assets/squat.jpeg', _maxSquat),
                        _buildExerciseCard('BENCH', 'assets/bench.jpeg', _maxBench),
                        _buildExerciseCard('DEADLIFT', 'assets/deadlift.jpeg', _maxDeadlift),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  flex: 2, 
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
                    decoration: const BoxDecoration(
                      color: darkAccentColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'HISTORIAL GENERAL',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                                );
                              },
                              icon: const Icon(Icons.show_chart, color: Colors.redAccent, size: 18),
                              label: const Text(
                                'Ver todo',
                                style: TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                              : _historialGeneral.isEmpty
                                  ? const Center(child: Text('Sin levantamientos recientes.', style: TextStyle(color: Colors.white54)))
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: _historialGeneral.length,
                                      itemBuilder: (context, index) {
                                        final set = _historialGeneral[index];
                                        final exerciseName = set['exercises']?['name'] ?? 'Ejercicio';
                                        
                                        return InkWell(
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => WorkoutDetailScreen(
                                                  workoutId: set['workout_id'],
                                                  date: set['workouts']?['date'] ?? '',
                                                ),
                                              ),
                                            );
                                            _obtenerHistorialGeneral();
                                            _cargarMarcasPersonales();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  exerciseName,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '${set['weight']}kg x ${set['reps']} ${set['rpe'] != null ? '@ RPE ${set['rpe']}' : ''}',
                                                      style: const TextStyle(color: Colors.white70),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}