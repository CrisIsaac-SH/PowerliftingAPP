import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class CompleteProfile extends StatefulWidget {
  const CompleteProfile({super.key});

  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<CompleteProfile> {
  // Controladores para leer el texto de los campos
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _pesoController = TextEditingController();
  String? _rolSeleccionado;
  
  bool _isLoading = false; // Para mostrar un indicador de carga

  Future<void> _guardarDatos() async {
  final nombre = _nombreController.text.trim();
  final edadTexto = _edadController.text.trim();
  final pesoTexto = _pesoController.text.trim();

  //validacion si hay campos vacios
  if (nombre.isEmpty || edadTexto.isEmpty || pesoTexto.isEmpty || _rolSeleccionado == null) {
    _mostrarError('Por favor, llena todos los campos');
    return;
  }

  //validacion que el nombre no tenga caracateres raros
  final regExpNombre = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
  if (!regExpNombre.hasMatch(nombre)) {
    _mostrarError('El nombre solo debe contener letras y espacios');
    return;
  }

  //validacion de rango de edad
  final edad = int.tryParse(edadTexto);
  if (edad == null || edad < 12 || edad > 100) {
    _mostrarError('Ingresa una edad válida (entre 12 y 100 años)');
    return;
  }

  //validad ranfo de peso
  final peso = double.tryParse(pesoTexto);
  if (peso == null || peso < 30 || peso > 300) {
    _mostrarError('Ingresa un peso válido (entre 30 y 300 kg)');
    return;
  }

  setState(() => _isLoading = true);
  // Guardamos los datos en Supabase
  try {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      await Supabase.instance.client.from('profiles').update({
        'full_name': nombre,
        'age': edad,
        'weight': peso,
        'role': _rolSeleccionado,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil guardado con éxito!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      _mostrarError('Error al guardar: $e');
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// Función auxiliar para mostrar mensajes de error
void _mostrarError(String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
  );
}

  @override
  void dispose() {
    // Es buena práctica limpiar los controladores al cerrar la pantalla
    _nombreController.dispose();
    _edadController.dispose();
    _pesoController.dispose();
    _rolSeleccionado = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Permite hacer scroll si el teclado tapa la pantalla
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cuéntanos sobre ti',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // Campo para el Nombre
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // Campo para la Edad
              TextField(
                controller: _edadController,
                keyboardType: TextInputType.number, // Muestra el teclado numérico
                decoration: const InputDecoration(
                  labelText: 'Edad',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // Campo para el Peso
              TextField(
                controller: _pesoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Teclado numérico con punto decimal
                decoration: const InputDecoration(
                  labelText: 'Peso (ej. 75.5 kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),

              // Campo para el Rol
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'coach', child: Text('Coach')),
                  DropdownMenuItem(value: 'athlete', child: Text('Atleta')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _rolSeleccionado = value;
                  });
                },
              ),

              // Botón de Guardar
              ElevatedButton(
                onPressed: _isLoading ? null : _guardarDatos,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GUARDAR PERFIL', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}