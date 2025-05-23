import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/activity_tracker_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _period = 0; // 0 = Week, 1 = Month, 2 = Year
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final activityService = context.read<ActivityTrackerService>();
    switch (_period) {
      case 0:
        final monday = _getMonday(_selectedDate);
        activityService.loadWeek(monday);
        break;
      case 1:
        final monthStart = DateTime(_selectedDate.year, _selectedDate.month);
        activityService.loadMonth(monthStart);
        break;
      case 2:
        final year = _selectedDate.year;
        activityService.loadYear(year);
        break;
    }
  }

  DateTime _getMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  String get _rangeLabel {
    final fmt = DateFormat('MM/dd');
    switch (_period) {
      case 0:
        final monday = _getMonday(_selectedDate);
        final sunday = monday.add(const Duration(days: 6));
        return '${fmt.format(monday)}-${fmt.format(sunday)}';
      case 1:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 2:
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return '';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2021),
      lastDate: DateTime.now(),
      locale: const Locale('en'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grad = const [Color(0xFFFF9240), Color(0xFFDD4733)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Consumer<ActivityTrackerService>(
            builder: (_, st, __) {
              List<int> data;
              switch (_period) {
                case 0:
                  final monday = _getMonday(_selectedDate);
                  data = st.weeklySteps(monday);
                  break;
                case 1:
                  final monthStart = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                  );
                  data = st.monthlySteps(monthStart);
                  break;
                case 2:
                  final year = _selectedDate.year;
                  data = st.yearlySteps(year);
                  break;
                default:
                  data = [];
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickDate,
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Text(
                              _period == 0
                                  ? 'This week'
                                  : _period == 1
                                  ? 'This month'
                                  : 'This year',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _rangeLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PeriodButton('Week', _period == 0, () {
                        setState(() => _period = 0);
                        _loadData();
                      }),
                      _PeriodButton('Month', _period == 1, () {
                        setState(() => _period = 1);
                        _loadData();
                      }),
                      _PeriodButton('Year', _period == 2, () {
                        setState(() => _period = 2);
                        _loadData();
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _Chart(
                        data: data,
                        isActivity: true,
                        period: _period,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 22),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    child: _ActivityStats(data: data, period: _period),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<int> data;
  final bool isActivity;
  final int period;

  const _Chart({
    required this.data,
    required this.isActivity,
    required this.period,
  });

  @override
  Widget build(BuildContext ctx) {
    final max = data.fold<int>(0, (p, e) => e > p ? e : p);
    final maxY = ((max + 999) ~/ 1000) * 1000 + 1000;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY.toDouble(),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 4,
          drawVerticalLine: false,
          getDrawingHorizontalLine:
              (v) => FlLine(color: Colors.white24, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 40,
              interval: maxY / 4,
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32, // 👈 Добавлен отступ для подписи X-оси
              interval: 1,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                String text = '';

                switch (period) {
                  case 0:
                    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (index >= 0 && index < weekDays.length) text = weekDays[index];
                    break;
                  case 1:
                    const shownDays = [0, 6, 12, 18, 24, 30];
                    if (shownDays.contains(index)) text = '${index + 1}';
                    break;
                  case 2:
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    if (index >= 0 && index < months.length) text = months[index];
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].toDouble())),
            isCurved: false,
            barWidth: 2,
            color: Colors.white,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeColor: Colors.white,
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStats extends StatelessWidget {
  final List<int> data;
  final int period;

  const _ActivityStats({required this.data, required this.period});

  @override
  Widget build(BuildContext context) {
    final totalSteps = data.fold<int>(0, (s, e) => s + e);
    final totalDistance = totalSteps * 0.0008;
    final totalCal = (totalSteps * 0.04).toInt();

    final count = data.where((e) => e > 0).length;
    final avgSteps = count > 0 ? (totalSteps / count).round() : 0;
    final avgDistance = count > 0 ? totalDistance / count : 0;
    final avgCal = count > 0 ? (totalCal / count).round() : 0;

    return Column(
      children: [
        Row(
          children: [
            _Item('Distance', totalDistance.toStringAsFixed(2), 'km'),
            _Item('Steps', '$totalSteps', 'steps'),
            _Item('Calories', '$totalCal', 'kcal'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Item('Avg dist/day', avgDistance.toStringAsFixed(2), 'km'),
            _Item('Avg steps/day', '$avgSteps', 'steps'),
            _Item('Avg cal/day', '$avgCal', 'kcal'),
          ],
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _Item(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext ctx) => Expanded(
    child: Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            children: [
              TextSpan(
                text: unit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
