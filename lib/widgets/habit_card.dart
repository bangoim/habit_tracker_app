import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../models/measurement_type.dart';
import '../models/streak_type.dart';
import '../screens/habit_detail_screen.dart';

class HabitCard extends StatelessWidget {
  final String habitId;

  const HabitCard({
    super.key,
    required this.habitId,
  });

  void _showInputDialog(BuildContext context, Habit habit) {
    // Verifica se o hábito já está completo para o dia
    final today = DateTime.now().toString().split(' ')[0];
    final currentValue = habit.completionStatus[today] as int? ?? 0;

    // Se o hábito já foi completado, não permite adicionar mais
    final bool isComplete = habit.streakType == StreakType.daily
        ? currentValue >= habit.completionsPerDay
        : currentValue >= habit.weeklyTarget;

    if (isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este hábito já foi concluído hoje!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String title = 'Quanto você completou?';
        if (habit.measurementType == MeasurementType.minutes) {
          title = 'Quantos minutos?';
        } else if (habit.measurementType == MeasurementType.quantity) {
          title = 'Quantas vezes?';
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                try {
                  // Tenta converter o texto para número
                  final value = int.tryParse(controller.text) ?? 0;
                  if (value > 0) {
                    // Calcula o valor máximo que pode ser adicionado para evitar exceder a meta
                    final int maxToAdd = habit.streakType == StreakType.daily
                        ? habit.completionsPerDay - currentValue
                        : habit.weeklyTarget - currentValue;

                    // Limita o valor a ser adicionado ao máximo permitido
                    final int valueToAdd = value > maxToAdd ? maxToAdd : value;

                    Provider.of<HabitProvider>(context, listen: false)
                        .addMinutesToHabit(habitId, valueToAdd);

                    // Se o valor adicionado for menor que o solicitado, mostra um aviso
                    if (valueToAdd < value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Apenas $valueToAdd foi adicionado para atingir a meta.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }

                    // Adicionamos um log para debug
                    debugPrint('Adicionados $valueToAdd minutos ao hábito $habitId');
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  debugPrint('Erro ao adicionar minutos: $e');
                  // Mostra um aviso em caso de erro
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao adicionar: $e')),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _showOptionsMenu(BuildContext context, Habit habit) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Ver detalhes'),
                onTap: () {
                  Navigator.pop(context);
                  // Navegar para a tela de detalhes
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HabitDetailScreen(habitId: habit.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reiniciar hábito'),
                onTap: () {
                  Navigator.pop(context);
                  _showResetConfirmation(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar hábito'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar edição de hábito
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Excluir hábito'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar exclusão de hábito
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reiniciar hábito'),
          content: const Text(
              'Isso vai apagar todo o progresso deste hábito. Tem certeza?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<HabitProvider>(context, listen: false)
                    .resetHabit(habitId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hábito reiniciado')),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Reiniciar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        final habit = habitProvider.habits.firstWhere(
          (h) => h.id == habitId,
          orElse: () => throw Exception('Hábito não encontrado: $habitId'),
        );

        final today = DateTime.now().toString().split(' ')[0];
        final currentValue = habit.completionStatus[today] as int? ?? 0;

        debugPrint(
            'Construindo HabitCard para ${habit.name} - valor atual: $currentValue');

        double progress;
        String targetText;
        bool isComplete;

        if (habit.streakType == StreakType.daily) {
          progress = habit.completionsPerDay > 0
              ? (currentValue / habit.completionsPerDay).clamp(0.0, 1.0)
              : 0.0;
          targetText = '/${habit.completionsPerDay}';
          isComplete = currentValue >= habit.completionsPerDay;
        } else {
          progress = habit.weeklyTarget > 0
              ? (currentValue / habit.weeklyTarget).clamp(0.0, 1.0)
              : 0.0;
          targetText = '/${habit.weeklyTarget}';
          isComplete = currentValue >= habit.weeklyTarget;
        }

        if (habit.measurementType == MeasurementType.minutes) {
          targetText += ' min';
        } else {
          targetText += ' vezes';
        }

        final habitColor = habit.color;
        final backgroundColor = habitColor.withOpacity(0.1);
        final progressColor = habitColor.withOpacity(0.3);
        // Cor mais forte quando completo
        final completedColor = habitColor.withOpacity(0.5);

        return Card(
          elevation: 0,
          color: backgroundColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            // Adicionando toque simples para ir para tela de detalhes
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HabitDetailScreen(habitId: habit.id),
                ),
              );
            },
            // Mantendo toque longo para menu de opções
            onLongPress: () => _showOptionsMenu(context, habit),
            child: Stack(
              children: [
                if (progress > 0)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isComplete ? completedColor : progressColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              habit.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  currentValue.toString(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  targetText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            if (habit.currentStreak > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${habit.currentStreak} ${habit.streakType == StreakType.daily ? 'dias' : 'semanas'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Altera o ícone de + para um checkmark quando o hábito estiver completo
                      IconButton(
                        icon: Icon(
                          isComplete ? Icons.check_circle : Icons.add_circle,
                        ),
                        iconSize: 32,
                        color: habitColor,
                        onPressed: () => _showInputDialog(context, habit),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
