import 'package:flutter/material.dart';//para lo visual 
import 'package:supabase_flutter/supabase_flutter.dart';//paara conectar con supabase
import 'package:google_fonts/google_fonts.dart';//tipografia

//importaciones de pantallas
import 'screens/login_screen.dart';

void main() async {
//prioridad de inicializar Supabase, aseguramos que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();
//iniciamos supabase
  await Supabase.initialize(
    url: 'https://fwtgsaujqkwhqwgzpebq.supabase.co',
    anonKey: 'sb_publishable_5VQPkVnMYK5of7DibF-RmQ_dog8zKB3',
  );
  

  // 3. iniciamos la app
  runApp(const PowerliftingApp());
}


class PowerliftingApp extends StatelessWidget {
  const PowerliftingApp({super.key});

//raiz de la app
  @override
  Widget build(BuildContext context) {
    //tema de la app y sus caracteristicas visuales
    return MaterialApp(
      title: 'Powerlifting AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      //pantalla inicial de la app que redirige al login
      home: const LoginScreen(),
    );
  }
}

//parte inneeserais, sirvio para partes incialse
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