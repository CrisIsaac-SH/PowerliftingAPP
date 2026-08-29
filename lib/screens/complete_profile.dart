import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'coach_home_screen.dart';
//importaciones de pantalla y componentes

class CompleteProfile extends StatefulWidget {
  const CompleteProfile({super.key});
//estado de pantalla
  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}


class _CompleteProfileState extends State<CompleteProfile> {
  //ctipos de campo para completar el perfil que se creo recientemente
  final _nombreController = TextEditingController();
  final _pesoController = TextEditingController();
  DateTime? _fechaNacimiento;
  String? _genero;
  bool _isCoach = false;

  bool _isLoading = false;

//funcion para seleccionar fecha en calendario
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 12)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF2C2C2C),
              onSurface: Colors.white,
            ),
          ),
          
          child: child!,
        );
      },
    );
    //si la fecha seleccionada es diferente a la actual se setea la fecha
    if (seleccionada != null && seleccionada != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = seleccionada;
      });
    }
  }


  //fucion para guardar losdatos en la db
  Future<void> _guardarDatos() async {
    //nombre completo y peso
    final nombre = _nombreController.text.trim();
    final pesoTexto = _pesoController.text.trim();

//si estan vacios los manda a crear
    if (nombre.isEmpty || pesoTexto.isEmpty || _fechaNacimiento == null || _genero == null) {
      _mostrarError('Por favor, llena todos los campos');
      return;
    }
//expresion regular para que soloa cepte letras y espacios jaja
    final regExpNombre = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!regExpNombre.hasMatch(nombre)) {
      _mostrarError('El nombre solo debe contener letras y espacios');
      return;
    }
//validacion  de peso minimo y maximo con sentido
    final peso = double.tryParse(pesoTexto);
    if (peso == null || peso < 30 || peso > 300) {
      _mostrarError('Ingresa un peso válido (entre 30 y 300 kg)');
      return;
    }

    setState(() => _isLoading = true);
    //se guarda en la db de supabase
    try {
      final user = Supabase.instance.client.auth.currentUser;
//si todo esta bien se guarda ee¿n la base de datos
      if (user != null) {
        await Supabase.instance.client.from('profiles').update({
          'full_name': nombre,
          'weight': peso,
          'birth_date': _fechaNacimiento!.toIso8601String().split('T')[0],
          'gender': _genero,
          'is_coach': _isCoach,
        }).eq('id', user.id);

//si todo esta bien muestra mensaje y los manda al hpesoomescreen del atleta
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Perfil guardado con éxito!'), backgroundColor: Colors.green),
          );
        // Decidimos a qué pantalla mandarlo según lo que eligió
        Widget siguientePantalla = _isCoach ? const CoachHomeScreen() : const HomeScreen();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => siguientePantalla),
        );
        }
      }
      //error si no se puede guardar en la db
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al guardar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
//funcion para mostrar error en pantalla
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }
//limpieza de datos se sie cierra la pantalla
  @override
  void dispose() {
    _nombreController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  //estilos varios para los cuadros de texto
  InputDecoration _customDecoration(String label, IconData icon) {
    return InputDecoration(
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
    );
  }

//estilos de la pantalla de completar perfil
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: const Text('Completa tu Perfil'),
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
              const Text(
                'CUÉNTANOS SOBRE TI',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              TextField(
                controller: _nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: _customDecoration('Nombre Completo', Icons.person),
              ),
              const SizedBox(height: 20),
              
              InkWell(
                onTap: () => _seleccionarFecha(context),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: _customDecoration('Fecha de Nacimiento', Icons.calendar_today),
                  child: Text(
                    _fechaNacimiento == null
                        ? 'Toca para seleccionar'
                        : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}',
                    style: TextStyle(
                      color: _fechaNacimiento == null ? Colors.white54 : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: _customDecoration('Género', Icons.people),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Femenino')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _genero = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _pesoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _customDecoration('Peso corporal actual (kg)', Icons.monitor_weight),
              ),
              const SizedBox(height: 30),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  border: Border.all(color: Colors.white12, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('¿Eres entrenador (Coach)?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Activa esto si preparas a otros atletas.', style: TextStyle(color: Colors.white54)),
                  value: _isCoach,
                  activeColor: Colors.redAccent,
                  activeTrackColor: Colors.red.withOpacity(0.4),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: const Color(0xFF333333),
                  onChanged: (bool value) {
                    setState(() {
                      _isCoach = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _guardarDatos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'GUARDAR PERFIL', 
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}