import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/one_rep_max.dart';
import 'ai_coach/pose_detector_view.dart'; // Asegúrate de ajustar esta ruta según donde creaste la carpeta

class RecordSetScreen extends StatefulWidget {
  final String? initialExercise;
  const RecordSetScreen({super.key, this.initialExercise});

  @override
  State<RecordSetScreen> createState() => _RecordSetScreenState();
}

class _RecordSetScreenState extends State<RecordSetScreen> {
  final _pesoController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController(); 
  
  double _1rmEstimado = 0.0;
  bool _isLoading = false;

  // Variables para la IA y el Video
  File? _videoFile;
  Map<String, dynamic>? _aiMetrics;

  List<Map<String, dynamic>> _exercises = [];
  String? _selectedExerciseId;
  bool _isLoadingExercises = true;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  // --- Descargar ejercicios de Supabase ---
  Future<void> _fetchExercises() async {
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id, name')
          .order('name', ascending: true);

      setState(() {
        _exercises = List<Map<String, dynamic>>.from(response);
        
        if (widget.initialExercise != null && _exercises.isNotEmpty) {
          try {
            final match = _exercises.firstWhere(
              (e) => e['name'].toString().toLowerCase().contains(widget.initialExercise!.toLowerCase()),
            );
            _selectedExerciseId = match['id'].toString();
          } catch (e) {
            _selectedExerciseId = null;
          }
        }

        _isLoadingExercises = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar ejercicios: $e')),
        );
        setState(() => _isLoadingExercises = false);
      }
    }
  }

  void _actualizar1RM() {
    final peso = double.tryParse(_pesoController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    setState(() {
      _1rmEstimado = PowerliftingUtils.calcular1RM(peso, reps);
    });
  }

  // --- Método para abrir la cámara con Visión Artificial ---
  Future<void> _abrirCamaraIA() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PoseDetectorView()),
    );

    if (resultado != null && resultado is Map) {
      setState(() {
        if (resultado['video_path'] != null) {
          _videoFile = File(resultado['video_path']);
        }
        _aiMetrics = resultado['ai_metrics'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Video y métricas de IA vinculados a la serie!'),
            backgroundColor: Colors.purpleAccent,
          ),
        );
      }
    }
  }

  Future<void> _guardarSet() async {
    if (_selectedExerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un ejercicio'), backgroundColor: Colors.orange),
      );
      return;
    }

    final peso = double.tryParse(_pesoController.text);
    final reps = int.tryParse(_repsController.text);
    final rpe = double.tryParse(_rpeController.text); 

    if (peso == null || reps == null || peso <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa valores de peso y reps válidos'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        final hoy = DateTime.now().toIso8601String().split('T')[0]; 
        String workoutId;

        final workoutExistente = await supabase
            .from('workouts')
            .select('id')
            .eq('user_id', user.id)
            .eq('date', hoy)
            .maybeSingle();
            
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

        // 1. Subida del video a Supabase Storage (si existe)
        String? videoUrl;
        if (_videoFile != null) {
          try {
            final fileExtension = _videoFile!.path.split('.').last;
            final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
            
            await supabase.storage
                .from('videos')
                .upload('sets_videos/$fileName', _videoFile!);

            videoUrl = supabase.storage
                .from('videos')
                .getPublicUrl('sets_videos/$fileName');
          } catch (e) {
            debugPrint('Error al subir video a Storage: $e');
          }
        }

        // 2. Inserción de la serie con URL de video y métricas de IA
        await supabase.from('sets').insert({
          'workout_id': workoutId,
          'exercise_id': _selectedExerciseId,
          'weight': peso,
          'reps': reps,
          if (rpe != null) 'rpe': rpe, 
          if (videoUrl != null) 'video_url': videoUrl,
          if (_aiMetrics != null) 'ai_metrics': _aiMetrics,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Serie y análisis guardados con éxito!'), backgroundColor: Colors.green),
          );
          _pesoController.clear();
          _repsController.clear();
          _rpeController.clear();
          setState(() {
            _1rmEstimado = 0.0;
            _videoFile = null;
            _aiMetrics = null;
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: const Text('Registrar Serie'),
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
              
              _isLoadingExercises
                  ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                  : DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Selecciona el Ejercicio',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.list_alt, color: Colors.redAccent),
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
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      value: _selectedExerciseId,
                      items: _exercises.map((exercise) {
                        return DropdownMenuItem<String>(
                          value: exercise['id'] as String,
                          child: Text(exercise['name'] as String),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedExerciseId = newValue;
                        });
                      },
                    ),
              
              const SizedBox(height: 16),
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
              
              const SizedBox(height: 24),

              // --- BOTÓN / TARJETA PARA IA COACH ---
              InkWell(
                onTap: _abrirCamaraIA,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    border: Border.all(
                      color: _videoFile != null ? Colors.purpleAccent : Colors.white24,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _videoFile != null ? Icons.check_circle : Icons.auto_awesome,
                        color: _videoFile != null ? Colors.greenAccent : Colors.purpleAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _videoFile != null ? 'Video de IA Listo' : 'Grabar con IA Coach',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _videoFile != null
                                  ? 'Análisis de técnica procesado'
                                  : 'Analiza tu postura en tiempo real',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _videoFile != null ? Icons.refresh : Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

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