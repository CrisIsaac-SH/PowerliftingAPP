import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';

class MeetsScreen extends StatefulWidget {
  final String athleteId;
  final String title;

  const MeetsScreen({super.key, required this.athleteId, this.title = 'Competencias'});

  @override
  State<MeetsScreen> createState() => _MeetsScreenState();
}

class _MeetsScreenState extends State<MeetsScreen> {
  final _service = TrainingService();
  bool _loading = true;
  List<Map<String, dynamic>> _meets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _service.meetsFor(widget.athleteId);
      if (mounted) setState(() { _meets = rows; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudieron cargar las competencias: $e')));
      }
    }
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    var date = DateTime.now().add(const Duration(days: 56));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: const Text('Nueva competencia', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                child: Text(TrainingService.ymd(date), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _service.addMeet(
        athleteId: widget.athleteId,
        name: nameController.text.trim(),
        date: date,
        createdBy: userId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: _add,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _meets.isEmpty
              ? const Center(child: Text('Todavía no hay competencias.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _meets.length,
                  itemBuilder: (context, index) {
                    final meet = _meets[index];
                    return Card(
                      color: const Color(0xFF252525),
                      child: ListTile(
                        title: Text(meet['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(meet['meet_date']?.toString() ?? '', style: const TextStyle(color: Colors.white54)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white38),
                          onPressed: () async {
                            await _service.deleteMeet(meet['id'].toString());
                            await _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
