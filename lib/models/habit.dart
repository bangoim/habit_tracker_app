import 'package:flutter/material.dart';
import 'streak_type.dart';
import 'measurement_type.dart';

class Habit {
  final String id;
  final String name;
  final StreakType streakType;
  final MeasurementType measurementType;
  final int completionsPerDay;     // Meta diária (quantidade ou minutos)
  final int weeklyTarget;          // Meta semanal (quantidade ou minutos)
  final Color color;
  Map<String, dynamic> completionStatus; // Armazena quantidade ou minutos por dia
  int currentStreak;

  // Novos campos
  List<bool> selectedDays;         // Dias da semana selecionados [dom, seg, ter, qua, qui, sex, sab]
  bool enableReminders;            // Se lembretes estão ativados
  double difficultyLevel;          // Nível de dificuldade (1-5)
  String notes;                    // Notas/descrição do hábito

  Habit({
    required this.id,
    required this.name,
    required this.streakType,
    required this.measurementType,
    required this.completionsPerDay,
    required this.weeklyTarget,
    required this.color,
    Map<String, dynamic>? completionStatus,
    this.currentStreak = 0,
    List<bool>? selectedDays,
    this.enableReminders = false,
    this.difficultyLevel = 3.0,
    this.notes = '',
  }) :
    completionStatus = completionStatus ?? {},
    selectedDays = selectedDays ?? List.filled(7, true); // Por padrão, todos os dias selecionados

  /// Verifica se o dia está completo baseado na meta diária
  bool isDayComplete(String dateStr) {
    final value = completionStatus[dateStr] as int? ?? 0;
    return value >= completionsPerDay;
  }

  /// Verifica se a semana está completa baseado na meta semanal
  bool isWeekComplete(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    var totalValue = 0;

    for (var i = 0; i < 7; i++) {
      final checkDate = startOfWeek.add(Duration(days: i));
      final dateStr = checkDate.toString().split(' ')[0];
      totalValue += completionStatus[dateStr] as int? ?? 0;
    }

    return totalValue >= weeklyTarget;
  }

  /// Calcula o streak atual com tratamento de erro melhorado
  int calculateStreak() {
    try {
      final today = DateTime.now();
      var streak = 0;
      var currentDate = today;
      var checkDays = 0;
      const maxCheckDays = 365; // Limitamos para evitar loops infinitos

      while (checkDays < maxCheckDays) {
        checkDays++;

        final dateStr = currentDate.toString().split(' ')[0];

        if (streakType == StreakType.daily) {
          if (!isDayComplete(dateStr)) {
            return streak;
          }
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else if (streakType == StreakType.weekly) {
          // Só verificamos o streak semanal aos domingos
          if (currentDate.weekday == 7) {
            if (!isWeekComplete(currentDate)) {
              return streak;
            }
            streak++;
          }
          currentDate = currentDate.subtract(const Duration(days: 1));
        }
      }

      return streak;
    } catch (e) {
      print('Erro ao calcular streak: $e');
      return currentStreak; // Retorna o valor atual em caso de erro
    }
  }

  /// Atualiza o status de conclusão para um dia específico
  void updateCompletion(String dateStr, int value) {
    // Garantir que o valor nunca seja negativo
    completionStatus[dateStr] = value < 0 ? 0 : value;
  }

  /// Método para obter o progresso atual de um hábito
  double getProgress() {
    if (streakType == StreakType.daily) {
      final today = DateTime.now().toString().split(' ')[0];
      final currentValue = completionStatus[today] as int? ?? 0;
      return completionsPerDay > 0 ? (currentValue / completionsPerDay).clamp(0.0, 1.0) : 0.0;
    } else {
      final today = DateTime.now();
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      var totalValue = 0;

      for (var i = 0; i < 7; i++) {
        final checkDate = startOfWeek.add(Duration(days: i));
        final dateStr = checkDate.toString().split(' ')[0];
        totalValue += completionStatus[dateStr] as int? ?? 0;
      }

      return weeklyTarget > 0 ? (totalValue / weeklyTarget).clamp(0.0, 1.0) : 0.0;
    }
  }
}
