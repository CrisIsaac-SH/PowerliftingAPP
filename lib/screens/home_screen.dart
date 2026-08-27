import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'record_set_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nombre = '';
  bool _isLoading = true;
  
  // Nuevas variables para el historial general
  bool _isLoadingHistory = true;
  List<dynamic> _historialGeneral = [];

  @override
  void initState() {
    super.initState();
    _obtenerDatosDelUsuario();
    _obtenerHistorialGeneral(); // Llamamos al historial al iniciar
  }

  Future<void> _obtenerDatosDelUsuario() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('full_name, role')
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
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // NUEVA FUNCIÓN: Obtener los últimos levantamientos de todos los ejercicios
  Future<void> _obtenerHistorialGeneral() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('sets')
            .select('exercise_name, weight, reps, rpe, workouts!inner(user_id, date)')
            .eq('workouts.user_id', user.id)
            .order('created_at', ascending: false) // Los más recientes primero
            .limit(10); // Mostramos solo los últimos 10 para resumen

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

  // Widget reutilizable para las tarjetas de los ejercicios
  Widget _buildExerciseCard(String title, String imagePath) {
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
            // Usamos await para esperar a que el usuario regrese de la pantalla
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordSetScreen(exerciseName: title),
              ),
            );
            // Cuando regresa, actualizamos el historial general automáticamente
            _obtenerHistorialGeneral();
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
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF333333);
    const darkAccentColor = Color(0xFF180A0A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Encabezado
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
                          'Bienvenido, "$_nombre"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Text(
                          'SBD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // Tarjetas de ejercicios
                Expanded(
                  flex: 3, // Le damos proporción a las tarjetas
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildExerciseCard('SQUAT', 'assets/squat.jpeg'),
                      _buildExerciseCard('BENCH', 'assets/bench.jpeg'),
                      _buildExerciseCard('DEADLIFT', 'assets/deadlift.jpeg'),
                    ],
                  ),
                ),

                // Sección inferior: HISTORIAL GENERAL DINÁMICO
                Expanded(
                  flex: 2, // Le damos proporción al historial
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
                        const Text(
                          'HISTORIAL GENERAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator())
                              : _historialGeneral.isEmpty
                                  ? const Center(child: Text('Sin levantamientos recientes.', style: TextStyle(color: Colors.white54)))
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: _historialGeneral.length,
                                      itemBuilder: (context, index) {
                                        final set = _historialGeneral[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                set['exercise_name'],
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '${set['weight']}kg x ${set['reps']} @ RPE ${set['rpe']}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                            ],
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
////////////////////////////////////////////////////////////////parte de arriba
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