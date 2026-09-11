import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/s3_config.dart';
import '../services/s3_video_service.dart';
import '../utils/one_rep_max.dart';
import 'ai_coach/pose_detector_view.dart';

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
  
  double _rmEstimado = 0.0;
  bool _isLoading = false;

  // Variables para la IA y el Video
  File? _videoFile;
  Map<String, dynamic>? _aiMetrics;
  List<Offset> _puntosTrayectoria = [];

  String? _selectedExerciseId;
  String _nombreEjercicioMostrado = '';
  bool _isLoadingExercises = true;

  @override
  void initState() {
    super.initState();
    _nombreEjercicioMostrado = widget.initialExercise ?? 'SQUAT';
    _fetchExercises();
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    super.dispose();
  }

  // --- Descargar y enlazar ejercicio fijo de Supabase ---
  Future<void> _fetchExercises() async {
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id, name')
          .order('name', ascending: true);

      final List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(response);

      String? ejercicioEncontradoId;
      String ejercicioEncontradoNombre = widget.initialExercise ?? 'SQUAT';

      final target = (widget.initialExercise ?? 'SQUAT').toLowerCase();

      for (var e in lista) {
        final name = (e['name'] ?? '').toString().toLowerCase();

        final esSquat = (target.contains('squat') || target.contains('sentadilla')) &&
            (name.contains('squat') || name.contains('sentadilla'));
        final esBench = (target.contains('bench') || target.contains('banca')) &&
            (name.contains('bench') || name.contains('banca'));
        final esDeadlift = (target.contains('deadlift') || target.contains('muerto')) &&
            (name.contains('deadlift') || name.contains('muerto'));

        if (esSquat || esBench || esDeadlift || name.contains(target) || target.contains(name)) {
          ejercicioEncontradoId = e['id'].toString();
          ejercicioEncontradoNombre = e['name'].toString();
          break;
        }
      }

      // Si no hubo coincidencia exacta pero hay ejercicios en la base de datos
      if (ejercicioEncontradoId == null && lista.isNotEmpty) {
        ejercicioEncontradoId = lista.first['id'].toString();
        ejercicioEncontradoNombre = lista.first['name'].toString();
      }

      if (mounted) {
        setState(() {
          _selectedExerciseId = ejercicioEncontradoId;
          _nombreEjercicioMostrado = ejercicioEncontradoNombre;
          _isLoadingExercises = false;
        });
      }
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
      _rmEstimado = PowerliftingUtils.calcular1RM(peso, reps);
    });
  }

  // --- Método para abrir la cámara con Visión Artificial ---
  Future<void> _abrirCamaraIA() async {
    final exerciseName = widget.initialExercise ?? _nombreEjercicioMostrado;

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoseDetectorView(
          exercise: exerciseName,
        ),
      ),
    );

    if (resultado != null && resultado is Map) {
      final metrics = resultado['ai_metrics'] as Map<String, dynamic>?;
      final videoPath = resultado['video_path'] as String?;

      List<Offset> puntos = [];
      if (metrics != null && metrics['trajectory_points'] != null && metrics['trajectory_points'] is List) {
        puntos = (metrics['trajectory_points'] as List)
            .map((item) => Offset(
                  (item['x'] as num).toDouble(),
                  (item['y'] as num).toDouble(),
                ))
            .toList();
      }

      setState(() {
        if (videoPath != null) {
          _videoFile = File(videoPath);
        }
        _aiMetrics = metrics;
        _puntosTrayectoria = puntos;

        // Si la IA contó repeticiones y el usuario aún no ingresó las reps, sugerirlas automáticamente
        if (metrics != null && metrics['reps_detected'] != null) {
          final repsIA = metrics['reps_detected'];
          if (repsIA is int && repsIA > 0 && _repsController.text.isEmpty) {
            _repsController.text = repsIA.toString();
            _actualizar1RM();
          }
        }
      });

      if (mounted) {
        final reps = metrics?['reps_detected'] ?? 0;
        final cuerpo = metrics?['body_detected'] == true ? 'Cuerpo detectado y bloqueado' : 'Análisis completado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$cuerpo! $reps reps registradas con preview disponible.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _guardarSet() async {
    if (_selectedExerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un ejercicio válido'), backgroundColor: Colors.orange),
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

    // PREVIEW DE CONFIRMACIÓN ANTES DE GUARDAR DEFINITIVAMENTE
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Confirmar Serie', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ejercicio: ${_nombreEjercicioMostrado.toUpperCase()}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('• Carga: $peso kg x $reps reps ${rpe != null ? "(@ RPE $rpe)" : ""}', style: const TextStyle(color: Colors.white70)),
            Text('• 1RM Estimado: ${_rmEstimado.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            if (_aiMetrics != null) ...[
              const Divider(color: Colors.white24, height: 16),
              Text(
                '• IA Coach: ${_aiMetrics!['reps_detected'] ?? 0} reps (${_aiMetrics!['valid_reps'] ?? 0} con ROM válido)',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
              ),
              if (_videoFile != null)
                const Text(
                  '• Video grabado: se subirá a S3 al guardar',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                ),
              Text(
                '• Profundidad alcanzada: ${(_aiMetrics!['best_angle'] as num?)?.toStringAsFixed(0) ?? 'N/A'}°',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '• Técnica: ${_aiMetrics!['technique_evaluation'] ?? 'Verificada'}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 178, 16, 16)),
            child: const Text('Confirmar y Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

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

        // 1. Subida del video a AWS S3 (si existe)
        String? videoUrl;
        if (_videoFile != null) {
          try {
            videoUrl = await S3VideoService.uploadSetVideo(
              file: _videoFile!,
              userId: user.id,
            );
          } catch (e) {
            debugPrint('Error al subir video a S3: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    S3Config.isConfigured
                        ? 'La serie se guardará, pero el video no se pudo subir: $e'
                        : 'Configura tu bucket S3 en lib/config/s3_config.dart para subir el video.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }

        // 2. Inserción de la serie con URL de video y métricas de IA
        await supabase.from('sets').insert({
          'workout_id': workoutId,
          'exercise_id': _selectedExerciseId,
          'weight': peso,
          'reps': reps,
          ...?((rpe != null) ? {'rpe': rpe} : null),
          ...?((videoUrl != null) ? {'video_url': videoUrl} : null),
          ...?((_aiMetrics != null) ? {'ai_metrics': _aiMetrics} : null),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Serie y análisis guardados con éxito!'), backgroundColor: Colors.green),
          );
          _pesoController.clear();
          _repsController.clear();
          _rpeController.clear();
          setState(() {
            _rmEstimado = 0.0;
            _videoFile = null;
            _aiMetrics = null;
            _puntosTrayectoria.clear();
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
              // Tarjeta 1RM Estimado
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
                        '${_rmEstimado.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // SELECCIÓN FIJA DEL EJERCICIO (REQUERIMIENTO: Sin desplegable de elegir, sólo indicar el seleccionado)
              _isLoadingExercises
                  ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center, color: Colors.redAccent, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EJERCICIO SELECCIONADO',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _nombreEjercicioMostrado.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 14, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  'Fijo',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              
              const SizedBox(height: 20),
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
                      color: _aiMetrics != null ? Colors.greenAccent : Colors.purpleAccent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _aiMetrics != null ? Icons.check_circle : Icons.auto_awesome,
                        color: _aiMetrics != null ? Colors.greenAccent : Colors.purpleAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _aiMetrics != null ? 'IA Coach Vinculado' : 'Grabar con IA Coach',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _aiMetrics != null
                                  ? (_videoFile != null
                                      ? 'Video listo para S3 · ${_aiMetrics!['reps_detected'] ?? 0} reps'
                                      : 'Cuerpo detectado y ${_aiMetrics!['reps_detected'] ?? 0} reps registradas')
                                  : 'Graba el video, detecta tu cuerpo y analiza ${widget.initialExercise ?? 'el ejercicio'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _aiMetrics != null ? Icons.refresh : Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // =========================================================
              // PREVIEW VISUAL DEL EJERCICIO ANTES DE GUARDAR LA SERIE
              // =========================================================
              if (_aiMetrics != null || _pesoController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.preview, color: Colors.cyanAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'PREVIEW DEL EJERCICIO - ${_nombreEjercicioMostrado.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Listo para guardar',
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Gráfico visual de la curva de trayectoria (si fue capturado con IA)
                      if (_puntosTrayectoria.isNotEmpty) ...[
                        Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: TrajectoryMiniPreviewPainter(
                                      points: _puntosTrayectoria,
                                      isDeep: (_aiMetrics?['valid_reps'] ?? 0) > 0,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  top: 6,
                                  left: 10,
                                  child: Text(
                                    'Curva de Bar Path / Desplazamiento',
                                    style: TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cuadrícula de datos del preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Carga Levantada:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(
                                  '${_pesoController.text.isEmpty ? "0" : _pesoController.text} kg x ${_repsController.text.isEmpty ? "0" : _repsController.text} reps',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('1RM Estimado:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(
                                  '${_rmEstimado.toStringAsFixed(1)} kg',
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            if (_aiMetrics != null) ...[
                              const Divider(color: Colors.white12, height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Repeticiones IA:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    '${_aiMetrics!['reps_detected'] ?? 0} (Válidas: ${_aiMetrics!['valid_reps'] ?? 0})',
                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Profundidad / ROM:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    '${(_aiMetrics!['best_angle'] as num?)?.toStringAsFixed(0) ?? 'N/A'}°',
                                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Evaluación Técnica:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      _aiMetrics!['technique_evaluation'] ?? 'Completado',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _guardarSet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save, color: Colors.white),
                label: _isLoading
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