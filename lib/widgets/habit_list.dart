import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import 'habit_card.dart';

class HabitList extends StatelessWidget {
  const HabitList({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        if (habitProvider.habits.isEmpty) {
          return const Center(
            child: Text('Nenhum hábito adicionado ainda!'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: habitProvider.habits.length,
          itemBuilder: (context, index) {
            final habit = habitProvider.habits[index];
            // Em vez de passar o objeto habit, passe apenas o ID
            return HabitCard(habitId: habit.id);
          },
        );
      },
    );
  }
}