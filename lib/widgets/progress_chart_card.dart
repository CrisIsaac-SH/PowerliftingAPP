import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';
import '../services/weight_unit_controller.dart';
import '../utils/one_rep_max.dart';
import 'rm_line_chart.dart';

class ProgressChartCard extends StatefulWidget {
  final String userId;
  final double height;

  const ProgressChartCard({super.key, required this.userId, this.height = 240});

  @override
  State<ProgressChartCard> createState() => _ProgressChartCardState();
}

class _ProgressChartCardState extends State<ProgressChartCard> {
  bool _loading = true;
  List<FlSpot> _squat = [];
  List<FlSpot> _bench = [];
  List<FlSpot> _deadlift = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProgressChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('sets')
          .select('weight, reps, status, exercises(name), workouts!inner(date, user_id)')
          .eq('workouts.user_id', widget.userId);
      final maxByDate = <String, Map<String, double>>{};
      for (final row in rows) {
        if (row['status'] != null && row['status'] != 'completed') continue;
        final date = row['workouts']?['date']?.toString() ?? '';
        if (date.isEmpty) continue;
        final key = TrainingService.liftKey((row['exercises']?['name'] ?? '').toString());
        if (key == null) continue;
        final weight = double.tryParse(row['weight'].toString()) ?? 0;
        final reps = int.tryParse(row['reps'].toString()) ?? 0;
        final rm = PowerliftingUtils.calcular1RM(weight, reps);
        final day = maxByDate.putIfAbsent(date, () => {'squat': 0, 'bench': 0, 'deadlift': 0});
        if (rm > day[key]!) day[key] = rm;
      }
      final dates = maxByDate.keys.toList()..sort();
      final squat = <FlSpot>[];
      final bench = <FlSpot>[];
      final deadlift = <FlSpot>[];
      final labels = <String>[];
      for (var i = 0; i < dates.length; i++) {
        final day = maxByDate[dates[i]]!;
        labels.add(dates[i].length >= 10 ? dates[i].substring(5) : dates[i]);
        if (day['squat']! > 0) squat.add(FlSpot(i.toDouble(), day['squat']!));
        if (day['bench']! > 0) bench.add(FlSpot(i.toDouble(), day['bench']!));
        if (day['deadlift']! > 0) deadlift.add(FlSpot(i.toDouble(), day['deadlift']!));
      }
      if (mounted) {
        setState(() {
          _squat = squat;
          _bench = bench;
          _deadlift = deadlift;
          _labels = labels;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ProgressChartCard: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<WeightUnitController>();
    return SizedBox(
      height: widget.height,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : RmLineChart(
              squatSpots: [for (final spot in _squat) FlSpot(spot.x, units.fromKg(spot.y))],
              benchSpots: [for (final spot in _bench) FlSpot(spot.x, units.fromKg(spot.y))],
              deadliftSpots: [for (final spot in _deadlift) FlSpot(spot.x, units.fromKg(spot.y))],
              dateLabels: _labels,
              unitSuffix: units.suffix,
            ),
    );
  }
}
