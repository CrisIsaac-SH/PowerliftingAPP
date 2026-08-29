import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/one_rep_max.dart';
//importaciones de utilidades y pantallas

class RecordSetScreen extends StatefulWidget {
  final String ejercicio; // Ej: 'Squat', 'Bench Press', 'Deadlift'
  //enfocado solo a los 3 ejercicios princiaples del powerlifitng

//constructor de la pantallas de screen
  const RecordSetScreen({super.key, required this.ejercicio});

  @override
  State<RecordSetScreen> createState() => _RecordSetScreenState();
}

//estado de la pantalla de registro de series
class _RecordSetScreenState extends State<RecordSetScreen> {
  //controladores de caracteristixas de las varieables
  final _pesoController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController(); 
  
  double _1rmEstimado = 0.0;
  bool _isLoading = false;

//funcion que maneja el rm 
  void _actualizar1RM() {
    //el peso y reps pasan arriba por los contoles
    final peso = double.tryParse(_pesoController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    //setea  el estado con el calculo de la rm en el calculo de one repmax
    setState(() {
      _1rmEstimado = PowerliftingUtils.calcular1RM(peso, reps);
    });
  }

//funcion que guarda el set del worjout
  Future<void> _guardarSet() async {
    //variables quehacen en cualidades 
    final peso = double.tryParse(_pesoController.text);
    final reps = int.tryParse(_repsController.text);
    final rpe = double.tryParse(_rpeController.text); 

    //si los campos estan nulos tira alertas que tiene que llenar
    if (peso == null || reps == null || peso <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa valores de peso y reps válidos'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      //intenta conextar a la db 
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      //si el user no es null guarda
      if (user != null) {
        final hoy = DateTime.now().toIso8601String().split('T')[0]; 
        String workoutId;

        final workoutExistente = await supabase
        //conecta a la base de datos todo lo esencial
            .from('workouts')
            .select('id')
            .eq('user_id', user.id)
            .eq('date', hoy)
            .maybeSingle();
        //si no hay workout lo crea
        if (workoutExistente == null) {
          final nuevoWorkout = await supabase
              .from('workouts')
              .insert({
                'user_id': user.id,
                'date': hoy,
              })
              .select('id')
              .single();
          workoutId = nuevoWorkout['id'];
        } else {
          workoutId = workoutExistente['id'];
        }

        await supabase.from('sets').insert({
          'workout_id': workoutId,
          'exercise_name': widget.ejercicio,
          'weight': peso,
          'reps': reps,
          if (rpe != null) 'rpe': rpe, 
        });

        //registro con exito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Serie registrada con éxito!'), backgroundColor: Colors.green),
          );
          _pesoController.clear();
          _repsController.clear();
          _rpeController.clear();
          setState(() => _1rmEstimado = 0.0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: Text('Registrar ${widget.ejercicio}'),
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        '1RM Estimado', 
                        style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_1rmEstimado.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildCustomTextField(
                controller: _pesoController,
                label: 'Peso levantado (kg)',
                icon: Icons.fitness_center,
                isDecimal: true,
              ),
              const SizedBox(height: 16),
              _buildCustomTextField(
                controller: _repsController,
                label: 'Repeticiones completadas',
                icon: Icons.repeat,
                isDecimal: false,
              ),
              const SizedBox(height: 16),
              _buildCustomTextField(
                controller: _rpeController,
                label: 'RPE (Opcional - ej. 8.5)',
                icon: Icons.speed,
                isDecimal: true,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _guardarSet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'GUARDAR SERIE', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget de ayuda para mantener el código limpio
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDecimal,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      onChanged: (_) => _actualizar1RM(),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.redAccent),
        filled: true,
        fillColor: const Color(0xFF252525),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}