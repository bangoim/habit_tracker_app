import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importa para o FilteringTextInputFormatter
import 'dart:convert'; // Importa para trabalhar com JSON
import 'package:http/http.dart' as http; // Importa para fazer requisições HTTP
import 'package:frontend/screens/habit_list_screen.dart'; // Importa a tela de listagem
// import 'package:frontend/utils/string_extensions.dart'; // Removido pois não é usado neste arquivo diretamente
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
      home: const HabitListScreen(),
    );
  }
}

class HabitFormScreen extends StatefulWidget {
  final Habit? habit;

  const HabitFormScreen({
    super.key,
    this.habit,
  });

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

  String? _selectedCountMethod;
  String? _selectedCompletionMethod;

  bool _formChanged = false;

  final List<String> _intervals = ['daily', 'weekly', 'monthly'];
  final Map<String, String> _intervalDisplayNames = {
    'daily': 'Diário',
    'weekly': 'Semanal',
    'monthly': 'Mensal',
  };

  final List<String> _completionTypes = ['quantity', 'minutes'];
  final Map<String, String> _completionTypeDisplayNames = {
    'quantity': 'Quantidade',
    'minutes': 'Minutos',
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
    // REVERTIDO PARA 10.0.2.2 para emulador Android
    String apiUrl = 'http://10.0.2.2:5000/habits';
    String successMessage = 'Hábito adicionado com sucesso!';
    String errorMessage = 'Erro ao adicionar hábito:';

    if (isEditing) {
      // REVERTIDO PARA 10.0.2.2 para emulador Android
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
            (_selectedCompletionMethod == 'quantity' || _selectedCompletionMethod == 'minutes')
                ? (_targetQuantityController.text.isEmpty
                    ? null
                    : int.parse(_targetQuantityController.text))
                : null,
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
        _formChanged = false; // Reseta o estado de alteração
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
        if (_formChanged) { // Simplificado: verifica apenas se houve alteração
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
                    onPressed: () => Navigator.pop(context), // Não precisa verificar _formChanged aqui
                  )
                  : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            onChanged: () { // Detecta mudanças em qualquer campo do formulário
              if (!_formChanged) {
                setState(() {
                  _formChanged = true;
                });
              }
            },
            child: ListView(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Hábito',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o nome do hábito';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
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
                      Icons.arrow_forward_ios,
                      size: 18,
                    ),
                  ),
                  onTap: () async {
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
                        _formChanged = true; // Marca como alterado
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
                const SizedBox(height: 16),
                if (_selectedCountMethod == 'weekly' ||
                    _selectedCountMethod == 'monthly')
                  QuantityInput(
                    controller: _targetDaysPerWeekController,
                    labelText: 'Dias Alvo por Período (ex: 4)',
                    onChanged: (value) {
                       if (!_formChanged) setState(() => _formChanged = true);
                    },
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
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
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
                      Icons.arrow_forward_ios,
                      size: 18,
                    ),
                  ),
                  onTap: () async {
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
                        _formChanged = true; // Marca como alterado
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
                const SizedBox(height: 16),
                if (_selectedCompletionMethod == 'quantity' || _selectedCompletionMethod == 'minutes')
                  QuantityInput(
                    controller: _targetQuantityController,
                    labelText:
                        _selectedCompletionMethod == 'quantity'
                            ? 'Quantidade Alvo (ex: 1x, 2x)'
                            : 'Minutos Alvo (ex: 200min)',
                    onChanged: (value) {
                      if (!_formChanged) setState(() => _formChanged = true);
                    },
                     validator: (value) {
                      if ((_selectedCompletionMethod == 'quantity' || _selectedCompletionMethod == 'minutes') &&
                          (value == null || value.isEmpty)) {
                        return 'Este campo é obrigatório para este tipo de completude.';
                      }
                      if (value != null &&
                          value.isNotEmpty &&
                          int.tryParse(value) == null) {
                        return 'Por favor, insira um número válido.';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        persistentFooterButtons: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: _submitHabit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: Text(buttonText),
            ),
          )
        ],
      ),
    );
  }
}

class QuantityInput extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;

  const QuantityInput({
    super.key,
    required this.controller,
    required this.labelText,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // Usar IntrinsicHeight para que a Row tente fazer seus filhos terem a mesma altura.
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          // CrossAxisAlignment.stretch fará com que os filhos da Row (TextFormField e o Container dos botões)
          // se estiquem verticalmente para preencher a altura determinada pelo IntrinsicHeight.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: labelText,
                  border: const OutlineInputBorder(),
                  // O contentPadding pode ser ajustado se necessário, mas o padrão
                  // geralmente funciona bem com CrossAxisAlignment.stretch.
                ),
                validator: validator,
                onChanged: onChanged,
                // textAlignVertical: TextAlignVertical.center, // Pode ajudar a centralizar o texto se a altura for maior.
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                // O raio da borda do TextFormField padrão é 4.0
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // A Row dos botões só ocupa o espaço necessário horizontalmente.
                children: [
                  // Usar um SizedBox para dar uma largura mínima e permitir que o IconButton preencha.
                  SizedBox(
                    width: 48, // Largura para o botão de diminuir
                    child: TextButton( // Alterado para TextButton para melhor controle de preenchimento e splash
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder( // Para remover o arredondamento extra do TextButton em si
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3.0), // Ajustar para alinhar com o raio do container
                            bottomLeft: Radius.circular(3.0),
                          )
                        ),
                      ),
                      onPressed: () {
                        int currentValue = int.tryParse(controller.text) ?? 0;
                        if (currentValue > 0) {
                          controller.text = (currentValue - 1).toString();
                          onChanged(controller.text);
                        }
                      },
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ),
                  // Divisor vertical
                  Container(
                    width: 1,
                    // A cor do divisor se estenderá devido ao CrossAxisAlignment.stretch do Row pai.
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(
                    width: 48, // Largura para o botão de aumentar
                    child: TextButton( // Alterado para TextButton
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                          shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(3.0),
                            bottomRight: Radius.circular(3.0),
                          )
                        ),
                      ),
                      onPressed: () {
                        int currentValue = int.tryParse(controller.text) ?? 0;
                        controller.text = (currentValue + 1).toString();
                        onChanged(controller.text);
                      },
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
