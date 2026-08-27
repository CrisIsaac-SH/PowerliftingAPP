import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

//importaciones de pantallas
import 'screens/login_screen.dart';

void main() async {
  // 1. Asegurarnos de que Flutter esté inicializado antes de llamar a servicios externos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar Supabase (Reemplazaremos estas claves pronto)
   
  await Supabase.initialize(
    url: 'https://fwtgsaujqkwhqwgzpebq.supabase.co',
    anonKey: 'sb_publishable_5VQPkVnMYK5of7DibF-RmQ_dog8zKB3',
  );
  

  // 3. Arrancar la aplicación
  runApp(const PowerliftingApp());
}

class PowerliftingApp extends StatelessWidget {
  const PowerliftingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Powerlifting AI',
      debugShowCheckedModeBanner: false, // Quita la etiqueta roja de "DEBUG"
      theme: ThemeData(
        // Configuramos un tema oscuro, ideal para apps de gimnasio
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// Esta es una pantalla temporal de inicio
class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Powerlifting AI Coach'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.fitness_center, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            Text(
              'Entorno configurado correctamente.',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Esperando conexión a base de datos...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
//ojala que aqui me abra el visual cuando vuelva a encender la compu