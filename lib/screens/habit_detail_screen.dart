import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/measurement_type.dart';
import '../models/streak_type.dart';
import '../providers/habit_provider.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    // Obter o hábito pelo ID
    final habitProvider = Provider.of<HabitProvider>(context);
    final habit = habitProvider.habits.firstWhere(
      (h) => h.id == habitId,
      orElse: () => throw Exception('Hábito não encontrado'),
    );

    // Dados simulados para os novos campos (em um app real, seriam armazenados no modelo Habit)
    const selectedDays = [true, true, true, true, true, true, true]; // Todos os dias
    const enableReminders = true;
    const difficultyLevel = 3.0;
    const notes = 'Este hábito é importante para minha saúde e bem-estar.';

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        backgroundColor: habit.color.withOpacity(0.8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner com informações principais
            _buildHeaderBanner(context, habit),

            // Detalhes do hábito
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Informações Básicas',
                    children: [
                      _buildInfoRow(
                        icon: Icons.category,
                        label: 'Tipo',
                        value: habit.streakType == StreakType.daily
                            ? 'Diário'
                            : 'Semanal',
                      ),
                      _buildInfoRow(
                        icon: Icons.straighten,
                        label: 'Medição',
                        value: habit.measurementType == MeasurementType.minutes
                            ? 'Minutos'
                            : 'Quantidade',
                      ),
                      _buildInfoRow(
                        icon: Icons.flag,
                        label: 'Meta diária',
                        value: '${habit.completionsPerDay} ${habit.measurementType == MeasurementType.minutes ? 'minutos' : 'vezes'}',
                      ),
                      _buildInfoRow(
                        icon: Icons.calendar_view_week,
                        label: 'Meta semanal',
                        value: '${habit.weeklyTarget} ${habit.measurementType == MeasurementType.minutes ? 'minutos' : 'vezes'}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Dias da semana (simulado)
                  _buildSection(
                    title: 'Dias da Semana',
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildDayChip('DOM', selectedDays[0], habit.color),
                          _buildDayChip('SEG', selectedDays[1], habit.color),
                          _buildDayChip('TER', selectedDays[2], habit.color),
                          _buildDayChip('QUA', selectedDays[3], habit.color),
                          _buildDayChip('QUI', selectedDays[4], habit.color),
                          _buildDayChip('SEX', selectedDays[5], habit.color),
                          _buildDayChip('SAB', selectedDays[6], habit.color),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Notificações (simulado)
                  _buildSection(
                    title: 'Notificações',
                    children: [
                      SwitchListTile(
                        title: const Text('Lembretes diários'),
                        subtitle: Text(
                          enableReminders
                              ? 'Ativado'
                              : 'Desativado',
                        ),
                        value: enableReminders,
                        onChanged: null, // Somente leitura
                        secondary: Icon(
                          enableReminders
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: enableReminders ? habit.color : Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Nível de dificuldade (simulado)
                  _buildSection(
                    title: 'Nível de Dificuldade',
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sentiment_very_satisfied, color: Colors.green),
                          Expanded(
                            child: Slider(
                              value: difficultyLevel,
                              min: 1.0,
                              max: 5.0,
                              divisions: 4,
                              label: difficultyLevel.toInt().toString(),
                              activeColor: habit.color,
                              onChanged: null, // Somente leitura
                            ),
                          ),
                          const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Fácil', style: TextStyle(fontSize: 12)),
                          Text('Difícil', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Notas (simulado)
                  _buildSection(
                    title: 'Descrição',
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(notes),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Diálogo para adicionar progresso
          _showAddProgressDialog(context, habit);
        },
        backgroundColor: habit.color,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Widget para o banner superior
  Widget _buildHeaderBanner(BuildContext context, Habit habit) {
    final today = DateTime.now().toString().split(' ')[0];
    final currentValue = habit.completionStatus[today] as int? ?? 0;

    // Calcula o progresso
    final targetValue = habit.streakType == StreakType.daily
        ? habit.completionsPerDay
        : habit.weeklyTarget;
    final progress = targetValue > 0
        ? (currentValue / targetValue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      color: habit.color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: habit.color,
                radius: 24,
                child: Icon(
                  _getHabitIcon(habit),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (habit.currentStreak > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              'Sequência: ${habit.currentStreak} ${habit.streakType == StreakType.daily ? 'dias' : 'semanas'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$currentValue/$targetValue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: habit.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(habit.color),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para seções de informação
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  // Widget para linhas de informação
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para chips de dias da semana
  Widget _buildDayChip(String day, bool selected, Color color) {
    return Chip(
      label: Text(day),
      backgroundColor: selected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
      labelStyle: TextStyle(
        color: selected ? color : Colors.grey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // Diálogo para adicionar progresso
  void _showAddProgressDialog(BuildContext context, Habit habit) {
    final controller = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            habit.measurementType == MeasurementType.minutes
                ? 'Quantos minutos?'
                : 'Quantas vezes?',
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text) ?? 0;
                if (value > 0) {
                  Provider.of<HabitProvider>(context, listen: false)
                      .addMinutesToHabit(habit.id, value);
                }
                Navigator.pop(context);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // Retorna um ícone baseado no nome do hábito
  IconData _getHabitIcon(Habit habit) {
    final name = habit.name.toLowerCase();

    if (name.contains('leitura') || name.contains('ler')) {
      return Icons.book;
    } else if (name.contains('exercício') || name.contains('academia') || name.contains('treino')) {
      return Icons.fitness_center;
    } else if (name.contains('água') || name.contains('beber')) {
      return Icons.water_drop;
    } else if (name.contains('meditação') || name.contains('meditar')) {
      return Icons.self_improvement;
    } else if (name.contains('correr') || name.contains('corrida')) {
      return Icons.directions_run;
    } else if (name.contains('estudo') || name.contains('estudar')) {
      return Icons.school;
    } else {
      return Icons.check_circle_outline;
    }
  }
}
