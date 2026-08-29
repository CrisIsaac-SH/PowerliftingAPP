import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'record_set_screen.dart';
import '../utils/one_rep_max.dart';
//importaciones de componentes y pantallas y funcion de rm


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
//estado de la pantalla principal del home
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //variables del user
  String _nombre = '';
  bool _isLoading = true;
  
  //variables para el historial general que esta debajo 
  bool _isLoadingHistory = true;
  List<dynamic> _historialGeneral = [];

  //marcas del deporte para mostrarlo en la suma
  double _maxSquat = 0.0;
  double _maxBench = 0.0;
  double _maxDeadlift = 0.0;


  @override
  //datos a mostrar
  void initState() {
    super.initState();
    _inicializarDatos();
  }
  //funcion para inicializar los datos del usuario y cargar marcas personales e historial
  Future<void> _inicializarDatos() async {
    await _obtenerDatosDelUsuario();
    _cargarMarcasPersonales();
    _obtenerHistorialGeneral();
  }

//fucnion que obtiene los datos del user y muestra 
  Future<void> _obtenerDatosDelUsuario() async {
    try {//si el user es nulo no hace nada
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        //si si hay user muestra el nombre y si es coach o no
        final data = await Supabase.instance.client
            .from('profiles')
            .select('full_name, is_coach')
            .eq('id', user.id)
            .single();
//si es coach lo redirige a la pantalla de coach
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

//funcion para cargar marcas y calculo 
  Future<void> _cargarMarcasPersonales() async {
    try {
      //conexion a supabase como lo de arriba
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      //si no hay user no hace nada
      if (user == null) return;
//ve a workouts y bisca sets y compara lo maximo 
      final response = await supabase
          .from('workouts')
          .select('id, sets(exercise_name, weight, reps)')
          .eq('user_id', user.id);
//variables que guarda desde workouts lo maximo de cada ejercicio
      double maxSq = 0;
      double maxBp = 0;
      double maxDl = 0;

//verifica cada workout y cada set
      for (var workout in response) {
        //mencionado arriba que recorre cada set
        final sets = workout['sets'] as List<dynamic>;
        //
        for (var s in sets) {
          //conversion de datos de minusculas y a string por si acaso
          final exercise = s['exercise_name'].toString().toLowerCase();
          //parseo de datos de peso 
          final weight = double.tryParse(s['weight'].toString()) ?? 0.0;
          //parseo identico que el de peso
          final reps = int.tryParse(s['reps'].toString()) ?? 0;
          
          //calculo del rm en utils
          final rmCalculado = PowerliftingUtils.calcular1RM(weight, reps);

          //si el ejercicio contiene squat o sentadilla compara si es mayor que el maximo y lo guardado en la varibale max
          if (exercise.contains('squat') || exercise.contains('sentadilla')) {
            if (rmCalculado > maxSq) maxSq = rmCalculado;
            //lo mismo pero en banca
          } else if (exercise.contains('bench') || exercise.contains('banca')) {
            if (rmCalculado > maxBp) maxBp = rmCalculado;
          } else if (exercise.contains('deadlift') || exercise.contains('muerto')) {
            if (rmCalculado > maxDl) maxDl = rmCalculado;
          }
        }
      }
//actaualizacion de los datos
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

//funcion para cargar el historial de las marcas
  Future<void> _obtenerHistorialGeneral() async {
    //si no esta montada la seccion no pasa nada
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    
    try {
      //aqui virificamos si hya conexion de datos y que no sea nulo
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('sets')
            .select('exercise_name, weight, reps, rpe, workouts!inner(user_id, date)')
            .eq('workouts.user_id', user.id)
            .order('created_at', ascending: false)
            .limit(10);

//si esta montada la seccion actualiza el historial
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

//widget que construye la tarjetade cada ejercicio
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
            ////usamos await para esperar que el user regrese de la pantalla de RecordSetScreen antes de actualizar los datos
            await Navigator.push(
              context,
              MaterialPageRoute(//aqui se redirige a la pantalla de registro de set y se pasa el nombre del ejercicio
                builder: (context) => RecordSetScreen(ejercicio: title),
              ),
            );
            //cuando vuelve se actualiza los datos de la homescreen
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

//widgert oara construir la pantalla
  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF333333);
    const darkAccentColor = Color(0xFF180A0A);
    final double total = _maxSquat + _maxBench + _maxDeadlift;

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
                    //etquieta que musetra el sbd completo
                    Positioned(
                      bottom: -15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          //parseo de datos a string y redondeo a 1 decimal
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

                //tarjetas de ejercicios
                Expanded(
                  flex: 3, 
                  child: RefreshIndicator(
                    onRefresh: _inicializarDatos,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        //imagenes de los ejercicios
                        _buildExerciseCard('SQUAT', 'assets/squat.jpeg', _maxSquat),
                        _buildExerciseCard('BENCH', 'assets/bench.jpeg', _maxBench),
                        _buildExerciseCard('DEADLIFT', 'assets/deadlift.jpeg', _maxDeadlift),
                      ],
                    ),
                  ),
                ),

                //parte del historial de los ejercicios
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
                        const Text(
                          'HISTORIAL GENERAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
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

// -------------------------------------------------------------parte de arriba con forma detallada
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

//
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}