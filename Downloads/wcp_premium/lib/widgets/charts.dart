// ════════════════════════════════════════════════════════════════
// charts.dart — small themed fl_chart wrappers reused by every data view
// (audience / product-analytics / attribution / auth / popup …). Each takes
// plain data + resolves colours from the app tokens, so screens stay terse.
// ════════════════════════════════════════════════════════════════
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../theme/tokens.dart';

/// One labelled, coloured value (for donut + bars).
class ChartDatum {
  const ChartDatum(this.label, this.value, [this.color]);
  final String label;
  final double value;
  final Color? color;
}

/// Default categorical palette (brand-violet first).
List<Color> chartPalette(AppColors c) => <Color>[
      c.accent,
      const Color(0xFF22D3EE),
      const Color(0xFF34D399),
      const Color(0xFFF472B6),
      const Color(0xFFFBBF24),
      const Color(0xFF60A5FA),
      const Color(0xFFA78BFA),
      const Color(0xFFFB7185),
    ];

// ── Donut (pie) with a centre label + a legend underneath ──────────
class WcpDonut extends StatelessWidget {
  const WcpDonut({super.key, required this.data, this.centerLabel, this.size = 150});
  final List<ChartDatum> data;
  final String? centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final List<Color> pal = chartPalette(c);
    final double total =
        data.fold<double>(0, (s, d) => s + (d.value < 0 ? 0 : d.value));
    if (total <= 0) {
      return SizedBox(
        height: size,
        child: Center(
            child: Text('داده‌ای نیست', style: TextStyle(color: c.tx3, fontSize: 12.5))),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: size * 0.30,
                sections: [
                  for (int i = 0; i < data.length; i++)
                    PieChartSectionData(
                      value: data[i].value <= 0 ? 0.0001 : data[i].value,
                      color: data[i].color ?? pal[i % pal.length],
                      radius: size * 0.18,
                      showTitle: false,
                    ),
                ],
              )),
              if (centerLabel != null)
                Text(centerLabel!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: c.tx1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            for (int i = 0; i < data.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: data[i].color ?? pal[i % pal.length],
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text(
                    '${data[i].label} ${Fmt.fa((data[i].value / total * 100).round())}٪',
                    style: TextStyle(fontSize: 11.5, color: c.tx2)),
              ]),
          ],
        ),
      ],
    );
  }
}

// ── Vertical bars with x-axis labels ───────────────────────────────
class WcpBars extends StatelessWidget {
  const WcpBars({super.key, required this.data, this.height = 170, this.color});
  final List<ChartDatum> data;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (data.isEmpty) {
      return SizedBox(
          height: height,
          child: Center(
              child: Text('داده‌ای نیست',
                  style: TextStyle(color: c.tx3, fontSize: 12.5))));
    }
    final double maxV =
        data.fold<double>(0, (m, d) => d.value > m ? d.value : m);
    final Color bar = color ?? c.accent;
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV <= 0 ? 1 : maxV * 1.2,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: c.line, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final int i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data[i].label,
                      style: TextStyle(fontSize: 9.5, color: c.tx3)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: data[i].value,
                color: data[i].color ?? bar,
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      )),
    );
  }
}

// ── Simple line (trend) ────────────────────────────────────────────
class WcpLine extends StatelessWidget {
  const WcpLine({super.key, required this.values, this.height = 150, this.color});
  final List<double> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (values.length < 2) {
      return SizedBox(
          height: height,
          child: Center(
              child: Text('داده کافی نیست',
                  style: TextStyle(color: c.tx3, fontSize: 12.5))));
    }
    final double maxV = values.reduce((a, b) => a > b ? a : b);
    final Color ln = color ?? c.accent;
    return SizedBox(
      height: height,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxV <= 0 ? 1 : maxV * 1.15,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: c.line, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            color: ln,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: ln.withAlpha(0x22),
            ),
          ),
        ],
      )),
    );
  }
}
