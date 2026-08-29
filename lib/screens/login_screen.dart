import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Importamos las pantallas necesarias

import 'complete_profile.dart';
import 'home_screen.dart';
import 'coach_home_screen.dart';

//clase principal
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
//estado de la pantalla
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //secciones para los campos del login y registro
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

//funcion cuando es iniciar sesion
  Future<void> _signIn() async {
    //setea la carga
    setState(() => _isLoading = true);
    //
    try {
      //intentando iniciaar sesion con supabase
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      //si todo esta bien se obtiene el perfil del usuario y se redirige a la pantalla siguiente
      //mounted para que no colpase la carga si se cambia de pantalla
      if (mounted && response.user != null) {
//-------------------si no esta completo el perfil lo manda a completar para ser coach o atleta
        final profile = await _supabase
            .from('profiles')
            .select('full_name, is_coach') 
            .eq('id', response.user!.id)
            .maybeSingle();
        final bool tienePerfilCompleto = profile != null &&
            profile['full_name'] != null &&
            profile['full_name'].toString().trim().isNotEmpty;
  //-----------------------          
        //verificamos si es coach o no
        final bool isCoach = profile != null && profile['is_coach'] == true;
//para enseñar que si se inicio sesion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sesión iniciada con éxito!'), backgroundColor: Colors.green),
        );
        

        Widget pantallaDestino;
        //si no tiene perfil copmpleto lo manda a completar, si es coach lo manda al coach y si es atleta la manda a home osea del atleta
        if (!tienePerfilCompleto) {
          pantallaDestino = const CompleteProfile();
        } else if (isCoach) {
          pantallaDestino = const CoachHomeScreen();
        } else {
          pantallaDestino = const HomeScreen();
        }

        //como en react se hace un navigator para cambiar la pantalla
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => pantallaDestino),
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

//funcion para crear cuenta
  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    //casi lo mismo que de iniciar sesion
    try {
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      //si ya hay con ese correo registrado muestra error
      if (response.user != null &&
          response.user!.identities != null &&
          response.user!.identities!.isEmpty) {
        _showError('Este correo electrónico ya está registrado. Intenta iniciar sesión.');
        return;
      }
//si todo esta bien registra y se manda el correo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Inicia sesión para continuar.'), backgroundColor: Colors.green),
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

//funcion para mostrar error en pantalla
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }
//para limpiar los cuadros de texto cuando se cierra pantalla
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

//estilo de la pantalla del login
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: const Text('POWERLIFTING AI COACH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),  
      body: Center(
        //scroll libre de errores de pantalla
        child: SingleChildScrollView( 
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.redAccent),
                const SizedBox(height: 60),
                
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _customDecoration('Correo Electrónico', Icons.email),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _customDecoration('Contraseña', Icons.lock),
                ),
                const SizedBox(height: 32),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                else ...[
                  ElevatedButton(
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('INICIAR SESIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  
                  OutlinedButton(
                    onPressed: _signUp,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CREAR CUENTA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}