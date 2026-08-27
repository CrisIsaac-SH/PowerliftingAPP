import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nombre = '';
  String _rol = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _obtenerDatosDelUsuario();
  }

  // Función para leer los datos desde Supabase
  Future<void> _obtenerDatosDelUsuario() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        // Buscamos en la tabla profiles la fila de este usuario
        final data = await Supabase.instance.client
            .from('profiles')
            .select('full_name, role')
            .eq('id', user.id)
            .single();

        setState(() {
          _nombre = data['full_name'] ?? 'Usuario';
          _rol = data['role'] ?? 'Desconocido';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantalla Principal'),
        //parte que permite el logout y regresa al login
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
            // Destruye todo el historial de navegación y regresa al Login
              Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
              );
            }
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Muestra un círculo de carga mientras lee la base de datos
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  Text(
                    '¡Hola, $_nombre!',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu rol actual es: $_rol',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }
}