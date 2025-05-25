import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importa para o FilteringTextInputFormatter
import 'dart:convert'; // Importa para trabalhar com JSON
import 'package:http/http.dart' as http; // Importa para fazer requisições HTTP
import 'package:frontend/screens/habit_list_screen.dart'; // Importa a tela de listagem
import 'package:frontend/utils/string_extensions.dart'; // Importa a extensão capitalize
import 'package:frontend/models/habit.dart'; // Importa o modelo Habit para uso na edição
import 'package:frontend/screens/selection_screen.dart'; // Importa a tela de seleção

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HabitListScreen(), // Tela inicial é a lista de hábitos
    );
  }
}

// A classe HabitFormScreen agora aceita um Habit opcional para edição
class HabitFormScreen extends StatefulWidget {
  final Habit? habit; // Hábito a ser editado (opcional)

  const HabitFormScreen({
    super.key,
    this.habit,
  }); // Construtor para receber o hábito

  @override
  _HabitFormScreenState createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _targetQuantityController =
      TextEditingController();
  final TextEditingController _targetDaysPerWeekController =
      TextEditingController();

  String? _selectedCountMethod; // Agora representa o "Intervalo"
  String? _selectedCompletionMethod; // Agora representa o "Tipo"

  bool _formChanged = false;

  // Listas e Mapas de Tradução para Intervalo
  final List<String> _intervals = ['daily', 'weekly', 'monthly'];
  final Map<String, String> _intervalDisplayNames = {
    'daily': 'Diário',
    'weekly': 'Semanal',
    'monthly': 'Mensal',
  };

  // Listas e Mapas de Tradução para Tipo de Completude
  final List<String> _completionTypes = ['quantity', 'minutes', 'none'];
  final Map<String, String> _completionTypeDisplayNames = {
    'quantity': 'Quantidade',
    'minutes': 'Minutos',
    'none': 'Nenhum',
  };

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      _nameController.text = widget.habit!.name;
      _descriptionController.text = widget.habit!.description ?? '';
      _selectedCountMethod = widget.habit!.countMethod;
      _selectedCompletionMethod = widget.habit!.completionMethod;
      _targetQuantityController.text =
          (widget.habit!.targetQuantity ?? '').toString();
      _targetDaysPerWeekController.text =
          (widget.habit!.targetDaysPerWeek ?? '').toString();
    }
  }

  Future<void> _submitHabit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bool isEditing = widget.habit != null;
    String apiUrl = 'http://10.0.2.2:5000/habits';
    String successMessage = 'Hábito adicionado com sucesso!';
    String errorMessage = 'Erro ao adicionar hábito:';

    if (isEditing) {
      apiUrl = 'http://10.0.2.2:5000/habits/${widget.habit!.id}';
      successMessage = 'Hábito atualizado com sucesso!';
      errorMessage = 'Erro ao atualizar hábito:';
    }

    try {
      final Map<String, dynamic> bodyData = {
        'name': _nameController.text,
        'description':
            _descriptionController.text.isEmpty
                ? null
                : _descriptionController.text,
        'count_method': _selectedCountMethod,
        'completion_method': _selectedCompletionMethod,
        'target_quantity':
            _selectedCompletionMethod == 'none'
                ? null
                : (_targetQuantityController.text.isEmpty
                    ? null
                    : int.parse(_targetQuantityController.text)),
        'target_days_per_week':
            _targetDaysPerWeekController.text.isEmpty
                ? null
                : int.parse(_targetDaysPerWeekController.text),
      };

      final response =
          isEditing
              ? await http.put(
                Uri.parse(apiUrl),
                headers: <String, String>{
                  'Content-Type': 'application/json; charset=UTF-8',
                },
                body: jsonEncode(bodyData),
              )
              : await http.post(
                Uri.parse(apiUrl),
                headers: <String, String>{
                  'Content-Type': 'application/json; charset=UTF-8',
                },
                body: jsonEncode(bodyData),
              );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
        _formChanged = false;
        Navigator.pop(context, true);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMessage ${errorData['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro de conexão: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle =
        widget.habit == null ? 'Cadastrar Hábito' : 'Editar Hábito';
    final String buttonText =
        widget.habit == null ? 'Adicionar Hábito' : 'Salvar Alterações';
    final bool isEditing = widget.habit != null;

    return WillPopScope(
      onWillPop: () async {
        if (_formChanged && !isEditing) {
          return await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Descartar alterações?'),
                    content: const Text(
                      'Você tem alterações não salvas. Deseja sair e perdê-las?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Não'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Sim'),
                      ),
                    ],
                  );
                },
              ) ??
              false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          leading:
              isEditing
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                  : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Hábito',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o nome do hábito';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (!_formChanged) setState(() => _formChanged = true);
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    if (!_formChanged) setState(() => _formChanged = true);
                  },
                ),
                // NOVO: TextFormField para "Intervalo" (abrirá uma tela de seleção)
                TextFormField(
                  readOnly: true, // Impede a digitação direta
                  controller: TextEditingController(
                    text:
                        _selectedCountMethod != null
                            ? _intervalDisplayNames[_selectedCountMethod]
                            : '',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Intervalo',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(
                      Icons.arrow_drop_down,
                    ), // Ícone de dropdown
                  ),
                  onTap: () async {
                    // Ao tocar, abre a SelectionScreen
                    final selectedValue = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SelectionScreen(
                              title: 'Selecionar Intervalo',
                              options: _intervalDisplayNames,
                              initialValue: _selectedCountMethod,
                            ),
                      ),
                    );
                    if (selectedValue != null) {
                      setState(() {
                        _selectedCountMethod = selectedValue;
                        if (!_formChanged) _formChanged = true;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione o intervalo.';
                    }
                    return null;
                  },
                ),
                if (_selectedCountMethod == 'weekly' ||
                    _selectedCountMethod == 'monthly')
                  TextFormField(
                    controller: _targetDaysPerWeekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dias Alvo por Período (ex: 4 de 7)',
                    ),
                    validator: (value) {
                      if ((_selectedCountMethod == 'weekly' ||
                              _selectedCountMethod == 'monthly') &&
                          (value == null || value.isEmpty)) {
                        return 'Este campo é obrigatório para hábitos semanais/mensais';
                      }
                      if (value != null &&
                          value.isNotEmpty &&
                          int.tryParse(value) == null) {
                        return 'Por favor, insira um número válido';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (!_formChanged) setState(() => _formChanged = true);
                    },
                  ),
                // NOVO: TextFormField para "Tipo" (abrirá uma tela de seleção)
                TextFormField(
                  readOnly: true, // Impede a digitação direta
                  controller: TextEditingController(
                    text:
                        _selectedCompletionMethod != null
                            ? _completionTypeDisplayNames[_selectedCompletionMethod]
                            : '',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(
                      Icons.arrow_drop_down,
                    ), // Ícone de dropdown
                  ),
                  onTap: () async {
                    // Ao tocar, abre a SelectionScreen
                    final selectedValue = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SelectionScreen(
                              title: 'Selecionar Tipo',
                              options: _completionTypeDisplayNames,
                              initialValue: _selectedCompletionMethod,
                            ),
                      ),
                    );
                    if (selectedValue != null) {
                      setState(() {
                        _selectedCompletionMethod = selectedValue;
                        if (!_formChanged) _formChanged = true;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione o tipo de completude.';
                    }
                    return null;
                  },
                ),
                // NOVO: Campo de Quantidade Alvo (com contador) - só aparece se o tipo NÃO for 'none'
                if (_selectedCompletionMethod != 'none')
                  QuantityInput(
                    // << NOVO WIDGET para o contador
                    controller: _targetQuantityController,
                    labelText:
                        _selectedCompletionMethod == 'quantity'
                            ? 'Quantidade Alvo (ex: 1x, 2x)'
                            : 'Minutos Alvo (ex: 200min)',
                    onChanged: (value) {
                      if (!_formChanged) setState(() => _formChanged = true);
                    },
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitHabit,
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: null,
      ),
    );
  }
}

// NOVO WIDGET: Para o campo de quantidade com botões de + e -
class QuantityInput extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator; // Adicionado validator

  const QuantityInput({
    super.key,
    required this.controller,
    required this.labelText,
    required this.onChanged,
    this.validator, // Adicionado validator
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, // Alinha na base
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ], // Apenas números
              decoration: InputDecoration(
                labelText: labelText,
                border: const OutlineInputBorder(),
              ),
              validator: validator, // Usa o validator passado
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 5), // Espaço menor entre o campo e os botões
          Container(
            // Container para agrupar os botões horizontalmente
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min, // Ocupa o mínimo de espaço horizontal
              children: [
                IconButton(
                  icon: const Icon(Icons.remove), // Ícone de menos
                  onPressed: () {
                    int currentValue = int.tryParse(controller.text) ?? 0;
                    if (currentValue > 0) {
                      controller.text = (currentValue - 1).toString();
                      onChanged(controller.text); // Notifica a alteração
                    }
                  },
                  padding:
                      EdgeInsets.zero, // Remove padding extra do IconButton
                  constraints: BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ), // Define um tamanho fixo
                ),
                Container(
                  // Divisor entre os botões (opcional)
                  height: 40,
                  width: 1,
                  color: Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.add), // Ícone de mais
                  onPressed: () {
                    int currentValue = int.tryParse(controller.text) ?? 0;
                    controller.text = (currentValue + 1).toString();
                    onChanged(controller.text); // Notifica a alteração
                  },
                  padding:
                      EdgeInsets.zero, // Remove padding extra do IconButton
                  constraints: BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ), // Define um tamanho fixo
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
