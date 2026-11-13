import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RmLineChart extends StatelessWidget {
  final List<FlSpot> squatSpots;
  final List<FlSpot> benchSpots;
  final List<FlSpot> deadliftSpots;
  final List<String> dateLabels;
  final String unitSuffix;

  const RmLineChart({
    super.key,
    required this.squatSpots,
    required this.benchSpots,
    required this.deadliftSpots,
    required this.dateLabels,
    required this.unitSuffix,
  });

  @override
  Widget build(BuildContext context) {
    if (squatSpots.isEmpty && benchSpots.isEmpty && deadliftSpots.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos suficientes para graficar.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      children: [
        Text(
          '1RM estimado ($unitSuffix)',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _legend('Squat', Colors.redAccent),
            _legend('Bench', Colors.blueAccent),
            _legend('Deadlift', Colors.greenAccent),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dateLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dateLabels[index],
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                if (squatSpots.isNotEmpty) _bar(squatSpots, Colors.redAccent),
                if (benchSpots.isNotEmpty) _bar(benchSpots, Colors.blueAccent),
                if (deadliftSpots.isNotEmpty) _bar(deadliftSpots, Colors.greenAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(String title, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }
}
