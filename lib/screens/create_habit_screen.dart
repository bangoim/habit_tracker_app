import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/streak_type.dart';
import '../models/measurement_type.dart';
import '../providers/habit_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController(text: '1');
  final _weeklyTargetController = TextEditingController(text: '1');
  StreakType _streakType = StreakType.daily;
  MeasurementType _measurementType = MeasurementType.quantity;
  Color _selectedColor = Colors.blue;

  // Novos campos para atender ao requisito de entrada de dados
  bool _enableReminders = false; // Para Switch
  List<bool> _selectedDays = [true, true, true, true, true, true, true]; // Para Checkboxes
  String _notes = ''; // Para campo de descrição

  // Lista de horários de lembretes
  List<TimeOfDay> _reminderTimes = [];

  final List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _weeklyTargetController.dispose();
    super.dispose();
  }

  Widget _buildStreakSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Objetivo de Streak',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<StreakType>(
          segments: const [
            ButtonSegment(
              value: StreakType.daily,
              label: Text('Diário'),
            ),
            ButtonSegment(
              value: StreakType.weekly,
              label: Text('Semanal'),
            ),
          ],
          selected: {_streakType},
          onSelectionChanged: (Set<StreakType> selection) {
            setState(() {
              _streakType = selection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMeasurementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Medição',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MeasurementType>(
          segments: const [
            ButtonSegment(
              value: MeasurementType.quantity,
              label: Text('Quantidade'),
            ),
            ButtonSegment(
              value: MeasurementType.minutes,
              label: Text('Minutos'),
            ),
          ],
          selected: {_measurementType},
          onSelectionChanged: (Set<MeasurementType> selection) {
            setState(() {
              _measurementType = selection.first;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildTargetInput(),
      ],
    );
  }

  Widget _buildTargetInput() {
    // Se for streak semanal e minutos, mostra apenas a meta semanal
    if (_streakType == StreakType.weekly && _measurementType == MeasurementType.minutes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meta de minutos por semana:',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final currentValue = int.parse(_weeklyTargetController.text);
                    if (currentValue > 1) {
                      _weeklyTargetController.text = (currentValue - 1).toString();
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _weeklyTargetController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final currentValue = int.parse(_weeklyTargetController.text);
                    _weeklyTargetController.text = (currentValue + 1).toString();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Para outros casos (diário ou semanal com quantidade)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta diária (só aparece se for streak diário OU se for semanal com quantidade)
        if (_streakType == StreakType.daily || _measurementType == MeasurementType.quantity) ...[
          Text(
            _measurementType == MeasurementType.minutes
                ? 'Quantos minutos por dia?'
                : 'Quantas vezes por dia?',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final currentValue = int.parse(_targetController.text);
                    if (currentValue > 1) {
                      _targetController.text = (currentValue - 1).toString();
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _targetController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final currentValue = int.parse(_targetController.text);
                    _targetController.text = (currentValue + 1).toString();
                  },
                ),
              ],
            ),
          ),
        ],

        // Meta semanal (só aparece se for streak semanal)
        if (_streakType == StreakType.weekly && _measurementType == MeasurementType.quantity) ...[
          const SizedBox(height: 16),
          Text(
            'Meta de vezes por semana:',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final currentValue = int.parse(_weeklyTargetController.text);
                    if (currentValue > 1) {
                      _weeklyTargetController.text = (currentValue - 1).toString();
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _weeklyTargetController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final currentValue = int.parse(_weeklyTargetController.text);
                    _weeklyTargetController.text = (currentValue + 1).toString();
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cor do Hábito',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == color
                        ? Colors.white
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 1. Componente para selecionar dias da semana (Checkboxes)
  Widget _buildDaysSection() {
    final weekdays = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dias da Semana',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(7, (index) {
            return FilterChip(
              selected: _selectedDays[index],
              label: Text(weekdays[index].substring(0, 3)),
              onSelected: (selected) {
                setState(() {
                  _selectedDays[index] = selected;
                });
              },
              selectedColor: _selectedColor.withOpacity(0.3),
            );
          }),
        ),
      ],
    );
  }

  // 2. Componente modificado para lembretes - agora abre um diálogo para selecionar horários
  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lembretes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Ativar lembretes'),
          subtitle: Text(
            _enableReminders
                ? 'Você receberá notificações para este hábito'
                : 'Sem notificações para este hábito'
          ),
          value: _enableReminders,
          onChanged: (value) {
            setState(() {
              _enableReminders = value;
              // Se ativar lembretes e não tiver nenhum horário definido, abre o diálogo
              if (_enableReminders && _reminderTimes.isEmpty) {
                _showAddReminderDialog();
              }
            });
          },
          secondary: Icon(
            _enableReminders ? Icons.notifications_active : Icons.notifications_off,
            color: _enableReminders ? _selectedColor : Colors.grey,
          ),
        ),

        // Lista de horários de lembretes
        if (_enableReminders && _reminderTimes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Horários de lembretes:'),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reminderTimes.length,
            itemBuilder: (context, index) {
              final time = _reminderTimes[index];
              return ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _reminderTimes.removeAt(index);
                    });
                  },
                ),
              );
            },
          ),

          // Botão para adicionar mais horários
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar horário'),
              onPressed: _showAddReminderDialog,
            ),
          ),
        ],
      ],
    );
  }

  // Diálogo para adicionar um novo horário de lembrete
  void _showAddReminderDialog() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        // Verificar se o horário já existe na lista
        if (!_reminderTimes.contains(pickedTime)) {
          _reminderTimes.add(pickedTime);
          // Ordenar horários
          _reminderTimes.sort((a, b) {
            int aMinutes = a.hour * 60 + a.minute;
            int bMinutes = b.hour * 60 + b.minute;
            return aMinutes.compareTo(bMinutes);
          });
        } else {
          // Mostrar mensagem de que o horário já existe
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este horário já foi adicionado!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  // Método para programar as notificações
  void _scheduleNotifications(String habitId, String habitName) async {
    // Esta função precisaria usar um plugin de notificações como flutter_local_notifications
    // Aqui apenas como demonstração do conceito

    // Para cada dia selecionado e cada horário, programar uma notificação
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        for (TimeOfDay time in _reminderTimes) {
          // Criaria uma notificação para este dia e horário
          print('Notificação para $habitName agendada para ${_getDayName(i)} às ${time.hour}:${time.minute}');

          // Aqui entraria a lógica de agendamento de notificação
          // Exemplo: FlutterLocalNotificationsPlugin().zonedSchedule(...)
        }
      }
    }
  }

  String _getDayName(int index) {
    final weekdays = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return weekdays[index];
  }

  // 4. Campo de texto para notas ou descrição
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descrição (opcional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Por que este hábito é importante para você?',
          ),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              _notes = value;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Hábito'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                final targetValue = int.parse(_targetController.text);
                final weeklyValue = int.parse(_weeklyTargetController.text);

                // Conversão dos horários de lembretes para algum formato armazenável
                List<String> reminderTimeStrings = [];
                for (var time in _reminderTimes) {
                  reminderTimeStrings.add('${time.hour}:${time.minute}');
                }

                final habitId = DateTime.now().toString();

                Provider.of<HabitProvider>(context, listen: false).addHabit(
                  name: _nameController.text,
                  streakType: _streakType,
                  measurementType: _measurementType,
                  completionsPerDay: targetValue,
                  weeklyTarget: weeklyValue,
                  color: _selectedColor,
                  // Campos adicionados:
                  selectedDays: _selectedDays,
                  enableReminders: _enableReminders,
                  difficultyLevel: 3.0, // Valor padrão, já que removemos o slider
                  notes: _notes,
                );

                // Se lembretes estiverem ativados, programar notificações
                if (_enableReminders && _reminderTimes.isNotEmpty) {
                  _scheduleNotifications(habitId, _nameController.text);
                }

                Navigator.of(context).pop();
              }
            },
            child: const Text('Concluir'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Hábito',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            _buildStreakSection(),
            const SizedBox(height: 24),
            _buildMeasurementSection(),
            const SizedBox(height: 24),
            _buildColorSection(),

            // Componentes modificados:
            const SizedBox(height: 24),
            _buildDaysSection(),
            const SizedBox(height: 24),
            _buildReminderSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }
}
