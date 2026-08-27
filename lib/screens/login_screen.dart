import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'complete_profile.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para leer lo que el usuario escribe
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Estado para mostrar un indicador de carga mientras Supabase responde
  bool _isLoading = false;

  // Instancia de Supabase
  final _supabase = Supabase.instance.client;

  // Función para Iniciar Sesión
  Future<void> _signIn() async {
  setState(() => _isLoading = true);
  try {
    final response = await _supabase.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted && response.user != null) {
      //verifica si el perfil del user ya esta completo
      final profile = await _supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', response.user!.id)
          .maybeSingle();

      final bool tienePerfilCompleto = profile != null &&
          profile['full_name'] != null &&
          profile['role'] != null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Sesión iniciada con éxito!')),
      );
        //si ya existe se va a home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => tienePerfilCompleto
              ? const HomeScreen()
              : const CompleteProfile(),
        ),
      );
    }
  } on AuthException catch (e) {
    _showError(e.message);
  } catch (e) {
    _showError('Error inesperado: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  // Función para Registrarse (Crear cuenta nueva)
  Future<void> _signUp() async {
  setState(() => _isLoading = true);
  try {
    final response = await _supabase.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    // Si la lista de identidades está vacía, el usuario ya existe en Supabase
    if (response.user != null &&
        response.user!.identities != null &&
        response.user!.identities!.isEmpty) {
      _showError('Este correo electrónico ya está registrado. Intenta iniciar sesión.');
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Inicia sesión para continuar.')),
      );
    }
  } on AuthException catch (e) {
    _showError(e.message);
  } catch (e) {
    _showError('Error inesperado: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  // Función auxiliar para mostrar errores
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada al Gimnasio'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 60),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true, // Oculta la contraseña
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton(
                onPressed: _signIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('INICIAR SESIÓN', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _signUp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('CREAR CUENTA', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}