import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanAthleteQrScreen extends StatefulWidget {
  const ScanAthleteQrScreen({super.key});

  @override
  State<ScanAthleteQrScreen> createState() => _ScanAthleteQrScreenState();
}

class _ScanAthleteQrScreenState extends State<ScanAthleteQrScreen> {
  bool _isProcessing = false;

  Future<void> _vincularAtletaDesdeQr(String rawValue) async {
    // Evitamos que escanee varias veces, PERO SIN setState para no apagar la cámara
    if (_isProcessing) return;
    _isProcessing = true; 

    try {
      final data = jsonDecode(rawValue);

      if (data['type'] != 'athlete_link' || data['athlete_id'] == null) {
        throw Exception('El código QR es inválido para esta aplicación.');
      }

      final athleteId = data['athlete_id'].toString();
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('Coach no autenticado.');
      }

      if (currentUser.id == athleteId) {
        throw Exception('No puedes agregarte a ti mismo.');
      }

      await supabase.from('coach_athletes').insert({
        'coach_id': currentUser.id,
        'athlete_id': athleteId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Atleta agregado a tu equipo!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); 
      }

    } on PostgrestException catch (e) {
      _isProcessing = false; // Liberamos el escáner sin setState
      if (mounted) {
        if (e.code == '23505') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este atleta ya pertenece a tu equipo.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de BD: ${e.message}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      _isProcessing = false; // Liberamos el escáner sin setState
      if (mounted) {
        final mensajeError = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR del atleta'),
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull;
          final rawValue = barcode?.rawValue;

          if (rawValue != null) {
            _vincularAtletaDesdeQr(rawValue);
          }
        },
      ),
    );
  }
}