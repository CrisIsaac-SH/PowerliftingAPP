import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordSetScreen extends StatefulWidget {
  final String exerciseName;
  const RecordSetScreen({super.key, required this.exerciseName});

  @override
  State<RecordSetScreen> createState() => _RecordSetScreenState();
}

class _RecordSetScreenState extends State<RecordSetScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  List<dynamic> _historialSets = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial(); // Carga el historial al abrir la pantalla
  }

  // --- NUEVA FUNCIÓN: Leer historial específico ---
  Future<void> _cargarHistorial() async {
    setState(() => _isLoadingHistory = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return;

      // Hacemos un INNER JOIN con workouts para filtrar por el usuario actual
      final data = await supabase
          .from('sets')
          .select('weight, reps, rpe, created_at, workouts!inner(user_id, date)')
          .eq('exercise_name', widget.exerciseName)
          .eq('workouts.user_id', user.id)
          .order('created_at', ascending: false) // Los más recientes primero
          .limit(20); // Traemos los últimos 20 para no saturar

      if (mounted) {
        setState(() {
          _historialSets = data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _guardarSet() async {
    final peso = double.tryParse(_weightController.text);
    final repeticiones = int.tryParse(_repsController.text);
    final rpe = double.tryParse(_rpeController.text);

    if (peso == null || repeticiones == null || rpe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa números válidos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) throw Exception('Usuario no autenticado');

      final hoy = DateTime.now().toIso8601String().split('T')[0];

      final workoutExistente = await supabase
          .from('workouts')
          .select('id')
          .eq('user_id', user.id)
          .eq('date', hoy)
          .maybeSingle();

      String workoutId;

      if (workoutExistente == null) {
        final nuevoWorkout = await supabase
            .from('workouts')
            .insert({'user_id': user.id, 'date': hoy})
            .select('id')
            .single();
        workoutId = nuevoWorkout['id'];
      } else {
        workoutId = workoutExistente['id'];
      }

      await supabase.from('sets').insert({
        'workout_id': workoutId,
        'exercise_name': widget.exerciseName,
        'weight': peso,
        'reps': repeticiones,
        'rpe': rpe,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Serie guardada con éxito!'), backgroundColor: Color.fromARGB(255, 40, 212, 46)),
        );
        
        // Limpiamos los campos para que pueda registrar la siguiente serie rápido
        _weightController.clear();
        _repsController.clear();
        _rpeController.clear();
        
        // Recargamos el historial para que aparezca la nueva serie al instante
        _cargarHistorial();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e', style: const TextStyle(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: Text(widget.exerciseName),
        backgroundColor: const Color(0xFF180A0A),
      ),
      body: Column(
        children: [
          // SECCIÓN SUPERIOR: FORMULARIO
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _rpeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'RPE', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _guardarSet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('GUARDAR SERIE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
          
          // DIVISOR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: const Color(0xFF180A0A),
            child: Text(
              'HISTORIAL DE ${widget.exerciseName}',
              style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
            ),
          ),

          // SECCIÓN INFERIOR: LISTA DE HISTORIAL
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _historialSets.isEmpty
                    ? const Center(child: Text('Aún no tienes series registradas.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _historialSets.length,
                        itemBuilder: (context, index) {
                          final set = _historialSets[index];
                          // Formateamos la fecha a YYYY-MM-DD
                          final fechaRaw = set['workouts']['date'].toString();
                          
                          return Card(
                            color: const Color(0xFF2C2C2C),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.fitness_center, color: Colors.white70),
                              title: Text(
                                '${set['weight']} kg x ${set['reps']} reps',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text('Fecha: $fechaRaw'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red[900],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'RPE ${set['rpe']}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}