import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../models/frequency_type.dart';
import '../models/measurement_type.dart';

class AddHabitDialog extends StatefulWidget {
  const AddHabitDialog({super.key});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  final _nameController = TextEditingController();
  MeasurementType _measurementType = MeasurementType.completion;
  int _targetValue = 1;
  FrequencyType _frequencyType = FrequencyType.daily;
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Segunda a Sexta por padrão
  Color _selectedColor = Colors.blue;

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
    super.dispose();
  }

  Widget _buildMeasurementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de medição:'),
        const SizedBox(height: 8),
        SegmentedButton<MeasurementType>(
          segments: const [
            ButtonSegment(
              value: MeasurementType.completion,
              label: Text('Conclusão'),
            ),
            ButtonSegment(
              value: MeasurementType.minutes,
              label: Text('Minutos'),
            ),
            ButtonSegment(
              value: MeasurementType.quantity,
              label: Text('Quantidade'),
            ),
          ],
          selected: {_measurementType},
          onSelectionChanged: (Set<MeasurementType> selection) {
            setState(() {
              _measurementType = selection.first;
              if (_measurementType == MeasurementType.completion) {
                _targetValue = 1;
              }
            });
          },
        ),
        if (_measurementType != MeasurementType.completion) ...[
          const SizedBox(height: 16),
          Text(
            _measurementType == MeasurementType.minutes
                ? 'Quantidade de minutos alvo:'
                : 'Quantidade alvo:',
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: _measurementType == MeasurementType.minutes
                  ? 'Ex: 200 minutos'
                  : 'Ex: 5 repetições',
            ),
            onChanged: (value) {
              setState(() {
                _targetValue = int.tryParse(value) ?? 1;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Intervalo de frequência:'),
        const SizedBox(height: 8),
        SegmentedButton<FrequencyType>(
          segments: const [
            ButtonSegment(
              value: FrequencyType.daily,
              label: Text('Diário'),
            ),
            ButtonSegment(
              value: FrequencyType.weekly,
              label: Text('Semanal'),
            ),
            ButtonSegment(
              value: FrequencyType.monthly,
              label: Text('Mensal'),
            ),
          ],
          selected: {_frequencyType},
          onSelectionChanged: (Set<FrequencyType> selection) {
            setState(() {
              _frequencyType = selection.first;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_frequencyType == FrequencyType.daily) _buildDailySelection(),
      ],
    );
  }

  Widget _buildDailySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecione os dias da semana:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (int i = 1; i <= 7; i++)
              FilterChip(
                label: Text(_getDayName(i)),
                selected: _selectedDays.contains(i),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(i);
                    } else {
                      _selectedDays.remove(i);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Seg';
      case 2:
        return 'Ter';
      case 3:
        return 'Qua';
      case 4:
        return 'Qui';
      case 5:
        return 'Sex';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return '';
    }
  }

  Widget _buildColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cor do hábito:'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Novo Hábito'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Hábito',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _buildMeasurementSection(),
            const SizedBox(height: 16),
            _buildFrequencySection(),
            const SizedBox(height: 16),
            _buildColorSelection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Provider.of<HabitProvider>(context, listen: false).addHabit(
                name: _nameController.text,
                frequencyType: _frequencyType,
                selectedDays: _selectedDays,
                targetValue: _targetValue,
                measurementType: _measurementType,
                color: _selectedColor,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
