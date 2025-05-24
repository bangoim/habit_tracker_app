// ATUALIZAÇÃO PARA providers/habit_provider.dart

import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/streak_type.dart';
import '../models/measurement_type.dart';

class HabitProvider with ChangeNotifier {
  final List<Habit> _habits = [];

  List<Habit> get habits => [..._habits];

  void addHabit({
  required String name,
  required StreakType streakType,
  required MeasurementType measurementType,
  required int completionsPerDay,
  required int weeklyTarget,
  required Color color,
  List<bool>? selectedDays,
  bool enableReminders = false,
  double difficultyLevel = 3.0,
  String notes = '',
}) {
  final habit = Habit(
    id: DateTime.now().toString(),
    name: name,
    streakType: streakType,
    measurementType: measurementType,
    completionsPerDay: completionsPerDay,
    weeklyTarget: weeklyTarget,
    color: color,
    selectedDays: selectedDays,
    enableReminders: enableReminders,
    difficultyLevel: difficultyLevel,
    notes: notes,
  );
  _habits.add(habit);
  debugPrint('Hábito adicionado: ${habit.name} (ID: ${habit.id})');
  notifyListeners();
}

  void addMinutesToHabit(String habitId, int minutes) {
    try {
      debugPrint('⚠️ TENTANDO ADICIONAR $minutes MINUTOS AO HÁBITO $habitId ⚠️');

      // Encontra o hábito
      final habitIndex = _habits.indexWhere((h) => h.id == habitId);
      if (habitIndex == -1) {
        debugPrint('❌ Hábito não encontrado!');
        return;
      }

      // Obtém a data de hoje
      final today = DateTime.now().toString().split(' ')[0];
      debugPrint('📅 Data de hoje: $today');

      // Obtém o valor atual
      final habit = _habits[habitIndex];
      final currentValue = habit.completionStatus[today] as int? ?? 0;
      debugPrint('🔢 Valor atual: $currentValue');

      // Calcula o novo valor
      final newValue = currentValue + minutes;
      debugPrint('🔢 Novo valor: $newValue');

      // Atualiza o valor
      habit.completionStatus[today] = newValue;
      debugPrint('✅ Valor atualizado no completionStatus');

      // Atualiza o streak se necessário
      updateStreakIfNeeded(habit, today);
      debugPrint('✅ Streak atualizado se necessário');

      // Força uma reconstrução de toda a UI
      debugPrint('📣 NOTIFICANDO OUVINTES PARA ATUALIZAR A UI 📣');
      notifyListeners();

      // Verificação final - printamos todos os valores atuais para debug
      debugPrint('📊 ESTADO ATUAL DOS HÁBITOS:');
      for (final h in _habits) {
        final value = h.completionStatus[today] as int? ?? 0;
        debugPrint('   - ${h.name} (ID: ${h.id}): $value');
      }
    } catch (e) {
      debugPrint('❌ ERRO AO ADICIONAR MINUTOS: $e');
    }
  }

  // Método para atualizar o streak quando necessário
  void updateStreakIfNeeded(Habit habit, String dateStr) {
    try {
      final date = DateTime.parse(dateStr);

      if (habit.streakType == StreakType.daily) {
        if (habit.isDayComplete(dateStr)) {
          // Só atualiza se o dia anterior também foi completo ou se é o início de um novo streak
          final yesterday = date.subtract(const Duration(days: 1));
          final yesterdayStr = yesterday.toString().split(' ')[0];

          if (habit.isDayComplete(yesterdayStr) || habit.currentStreak == 0) {
            habit.currentStreak++;
            debugPrint('🔥 Streak de ${habit.name} atualizado para ${habit.currentStreak}');
          }
        }
      } else if (habit.streakType == StreakType.weekly) {
        // Para streaks semanais, verificamos se a semana está completa apenas no domingo
        if (date.weekday == 7 && habit.isWeekComplete(date)) {
          final lastWeek = date.subtract(const Duration(days: 7));
          if (habit.isWeekComplete(lastWeek) || habit.currentStreak == 0) {
            habit.currentStreak++;
            debugPrint('🔥 Streak de ${habit.name} atualizado para ${habit.currentStreak}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar streak: $e');
    }
  }

  // Reinicia um hábito (útil para quando você precisa "resetar" um hábito que travou)
  void resetHabit(String habitId) {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex != -1) {
      _habits[habitIndex].completionStatus = {};
      _habits[habitIndex].currentStreak = 0;
      debugPrint('🗑️ Hábito ${_habits[habitIndex].name} resetado');
      notifyListeners();
    } else {
      debugPrint('❌ Não foi possível resetar: hábito não encontrado');
    }
  }
}
