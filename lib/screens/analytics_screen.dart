// =============================================================================
// LinkLocker – Analytics Screen (Clicks & Leads)
// Requirements: fl_chart ^1.1.1, csv ^6.0.0
// =============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart'; // ✅ Added to fix ListToCsvConverter

final _sb = Supabase.instance.client;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  String? _error;
  List<_Point> _clicks = [];
  List<_Point> _leads = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final clicks = await _tryDaily('daily_clicks', 'click_count')
          ?? await _fallbackDaily('clicks');
      final leads = await _tryDaily('daily_leads', 'lead_count')
          ?? await _fallbackDaily('leads');

      setState(() {
        _clicks = clicks;
        _leads = leads;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load analytics: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<_Point>?> _tryDaily(String view, String countField) async {
    try {
      final uid = _sb.auth.currentUser!.id;
      final data = await _sb.from(view)
          .select('day, $countField')
          .eq('user_id', uid)
          .order('day', ascending: true);
      return (data as List)
          .map((m) => _Point.fromView(m, countField))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<_Point>> _fallbackDaily(String table) async {
    final uid = _sb.auth.currentUser!.id;
    final data = await _sb
        .from(table)
        .select('created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: true);
    final Map<DateTime, int> byDay = {};
    for (final row in data as List) {
      final ts = DateTime.parse(row['created_at'] as String).toLocal();
      final day = DateTime(ts.year, ts.month, ts.day);
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    final points = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return points.map((e) => _Point(e.key, e.value)).toList();
  }

  void _exportCsv() {
    final rows = <List<dynamic>>[
      ['day', 'clicks', 'leads'],
    ];
    final allDays = <DateTime>{
      ..._clicks.map((e) => e.day),
      ..._leads.map((e) => e.day),
    }.toList()
      ..sort((a, b) => a.compareTo(b));

    for (final d in allDays) {
      final c = _clicks.firstWhere((p) => p.day == d, orElse: () => _Point(d, 0)).value;
      final l = _leads.firstWhere((p) => p.day == d, orElse: () => _Point(d, 0)).value;
      rows.add([d.toIso8601String().split('T').first, c, l]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export CSV'),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _clicks.isEmpty && _leads.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(title: 'Clicks', child: _TimeSeriesChart(points: _clicks)),
                      const SizedBox(height: 24),
                      _Section(title: 'Leads', child: _TimeSeriesChart(points: _leads, colorSchemeIndex: 1)),
                    ],
                  ),
                ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _TimeSeriesChart extends StatelessWidget {
  final List<_Point> points;
  final int colorSchemeIndex;
  const _TimeSeriesChart({required this.points, this.colorSchemeIndex = 0});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No data yet'));
    }
    final base = Theme.of(context).colorScheme;
    final color = [base.primary, base.tertiary, base.secondary, base.error][colorSchemeIndex % 4];

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].value.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 6).clamp(1, 10).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final d = points[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: color,
            dotData: const FlDotData(show: false),
            spots: spots,
          )
        ],
      ),
    );
  }
}

class _Point {
  final DateTime day;
  final int value;
  _Point(this.day, this.value);
  factory _Point.fromView(Map<String, dynamic> m, String countField) {
    final dayStr = m['day'] as String;
    final d = DateTime.parse(dayStr).toLocal();
    final v = (m[countField] as num).toInt();
    return _Point(DateTime(d.year, d.month, d.day), v);
  }
}