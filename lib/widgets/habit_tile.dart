import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/streak_type.dart';
import '../models/measurement_type.dart';
import '../providers/habit_provider.dart';

class HabitTile extends StatelessWidget {
  final Habit habit;

  const HabitTile({
    super.key,
    required this.habit,
  });

  Widget _buildValueInput(BuildContext context, String dateStr) {
    final currentValue = habit.completionStatus[dateStr] as int? ?? 0;
    final String unit = habit.measurementType == MeasurementType.minutes
        ? ' min'
        : ' x';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: currentValue > 0
              ? () {
                  Provider.of<HabitProvider>(context, listen: false)
                      .updateHabitCompletion(habit.id, dateStr, currentValue - 1);
                }
              : null,
        ),
        Text('$currentValue$unit'),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Provider.of<HabitProvider>(context, listen: false)
                .updateHabitCompletion(habit.id, dateStr, currentValue + 1);
          },
        ),
      ],
    );
  }

  Widget _buildStreakIndicator() {
    if (habit.currentStreak == 0) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, color: Colors.orange),
        Text(
          'x${habit.currentStreak}',
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getFrequencyText() {
    switch (habit.streakType) {
      case StreakType.daily:
        return 'Meta: ${habit.completionsPerDay}${_getUnitText()} por dia';
      case StreakType.weekly:
        return 'Meta: ${habit.weeklyTarget}${_getUnitText()} por semana';
    }
  }

  String _getUnitText() {
    return habit.measurementType == MeasurementType.minutes ? ' min' : 'x';
  }

  String _getProgressText(String dateStr) {
    final date = DateTime.parse(dateStr);

    switch (habit.streakType) {
      case StreakType.daily:
        final value = habit.completionStatus[dateStr] as int? ?? 0;
        return '$value/${habit.completionsPerDay}${_getUnitText()}';

      case StreakType.weekly:
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        var total = 0;
        for (var i = 0; i < 7; i++) {
          final checkDate = startOfWeek.add(Duration(days: i));
          final checkDateStr = checkDate.toString().split(' ')[0];
          total += habit.completionStatus[checkDateStr] as int? ?? 0;
        }
        return '$total/${habit.weeklyTarget}${_getUnitText()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toString().split(' ')[0];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: habit.color,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(habit.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFrequencyText()),
            Text(_getProgressText(today)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStreakIndicator(),
            const SizedBox(width: 8),
            _buildValueInput(context, today),
          ],
        ),
      ),
    );
  }
}
