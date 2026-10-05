import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/weight_unit_controller.dart';

class WeightUnitSwitchTile extends StatelessWidget {
  const WeightUnitSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<WeightUnitController>();

    return SwitchListTile(
      secondary: const Icon(Icons.straighten, color: Colors.white),
      title: const Text('Libras', style: TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(
        units.usePounds
            ? 'Activado: los pesos se muestran en lb'
            : 'Desactivado: los pesos se muestran en kg',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      value: units.usePounds,
      activeThumbColor: Colors.redAccent,
      activeTrackColor: Colors.redAccent.withValues(alpha: 0.45),
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: const Color(0xFF333333),
      onChanged: (value) async {
        try {
          await context.read<WeightUnitController>().setUsePounds(value);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo guardar la unidad: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }
}
