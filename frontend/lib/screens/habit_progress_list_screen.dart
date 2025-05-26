// frontend/lib/screens/habit_progress_list_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/habit.dart';
import '../models/category_model.dart';
import 'package:frontend/screens/habit_form_screen.dart'; // Ainda precisa para ações de check/edição (se passadas)
import 'package:frontend/models/habit_record.dart';
import 'package:frontend/widgets/habit_card_with_heatmap.dart'; // Importa o widget de cartão com heatmap

class HabitProgressListScreen extends StatefulWidget {
  const HabitProgressListScreen({super.key});

  @override
  State<HabitProgressListScreen> createState() =>
      _HabitProgressListScreenState();
}

class _HabitProgressListScreenState extends State<HabitProgressListScreen> {
  Future<List<Habit>>? _futureDisplayedHabits;
  List<CategoryModel> _categoriesInUseForFilter = [];
  int? _selectedCategoryIdFilter;

  final String _baseUrl =
      'http://10.0.2.2:5000'; // Ajuste este IP se necessário

  @override
  void initState() {
    super.initState();
    _loadAllHabitsAndSetupFilters();
  }

  Future<void> _loadAllHabitsAndSetupFilters() async {
    if (!mounted) return;

    setState(() {
      _selectedCategoryIdFilter = null;
      _futureDisplayedHabits = fetchHabits(categoryId: null);
    });

    try {
      final List<Habit>? allHabits = await _futureDisplayedHabits;

      if (allHabits != null && mounted) {
        Set<CategoryModel> usedCategoriesSet = {};
        for (var habit in allHabits) {
          for (var category in habit.categories) {
            usedCategoriesSet.add(category);
          }
        }
        List<CategoryModel> sortedUsedCategories = usedCategoriesSet.toList();
        sortedUsedCategories.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _categoriesInUseForFilter = sortedUsedCategories;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar e configurar filtros: $e')),
        );
        setState(() {
          _categoriesInUseForFilter = [];
          _futureDisplayedHabits = Future.value([]);
        });
      }
    }
  }

  void _filterHabitsBy({int? categoryId}) {
    if (!mounted) return;
    setState(() {
      _selectedCategoryIdFilter = categoryId;
      _futureDisplayedHabits = fetchHabits(categoryId: categoryId);
    });
  }

  Future<List<Habit>> fetchHabits({int? categoryId}) async {
    String apiUrl = '$_baseUrl/habits';
    if (categoryId != null) {
      apiUrl += '?category_id=$categoryId';
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Habit.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar hábitos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Falha ao conectar com o backend: $e');
    }
  }

  Future<void> _refreshDataAfterModification() async {
    await _loadAllHabitsAndSetupFilters();
  }

  // Métodos de _recordHabitCompletion e _showQuantityDialog podem ser removidos daqui
  // se não for possível registrar hábitos da tela de progresso.
  // Vou mantê-los por enquanto, caso o botão de check seja útil aqui.
  Future<void> _recordHabitCompletion(
    int habitId,
    String completionMethod, {
    int? quantityCompleted,
  }) async {
    final String apiUrl = '$_baseUrl/habit_records';
    final String recordDate = DateTime.now().toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'habit_id': habitId,
          'record_date': recordDate,
          'quantity_completed': quantityCompleted,
        }),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hábito registrado com sucesso!')),
        );
        _refreshDataAfterModification();
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hábito já registrado para hoje!')),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar hábito: ${errorData['error']}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão ao registrar: $e')),
      );
    }
  }

  Future<void> _showQuantityDialog(Habit habit) async {
    TextEditingController quantityController = TextEditingController();
    final formKeyDialog = GlobalKey<FormState>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Registrar ${habit.name}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKeyDialog,
              child: ListBody(
                children: <Widget>[
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          habit.completionMethod == 'quantity'
                              ? 'Quantidade realizada'
                              : 'Minutos realizados',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Por favor, insira um valor';
                      if (int.tryParse(value) == null)
                        return 'Por favor, insira um número válido';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Registrar'),
              onPressed: () {
                if (formKeyDialog.currentState!.validate()) {
                  _recordHabitCompletion(
                    habit.id,
                    habit.completionMethod,
                    quantityCompleted: int.parse(quantityController.text),
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // Fim dos métodos de registro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progresso dos Hábitos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllHabitsAndSetupFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_futureDisplayedHabits != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        label: Text(
                          'Todas',
                          style: TextStyle(
                            color:
                                _selectedCategoryIdFilter == null
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        selected: _selectedCategoryIdFilter == null,
                        onSelected: (bool selected) {
                          _filterHabitsBy(categoryId: null);
                        },
                        checkmarkColor:
                            _selectedCategoryIdFilter == null
                                ? Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer
                                : null,
                        selectedColor:
                            _selectedCategoryIdFilter == null
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            8.0,
                          ), // Mais arredondado
                          side: BorderSide(
                            color:
                                _selectedCategoryIdFilter == null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                          ),
                        ),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surface, // Fundo do chip
                      ),
                    ),
                    ..._categoriesInUseForFilter.map((category) {
                      bool isSelected =
                          _selectedCategoryIdFilter == category.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FilterChip(
                          label: Text(
                            category.name,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            _filterHabitsBy(
                              categoryId: selected ? category.id : null,
                            );
                          },
                          checkmarkColor:
                              isSelected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                  : null,
                          selectedColor:
                              isSelected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer
                                  : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8.0,
                            ), // Mais arredondado
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                            ),
                          ),
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surface, // Fundo do chip
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Habit>>(
              future: _futureDisplayedHabits,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao carregar hábitos: ${snapshot.error}\nPor favor, tente atualizar.',
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum hábito encontrado.'));
                } else {
                  final habits = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 0,
                      top: 0,
                      left: 8.0,
                      right: 8.0,
                    ),
                    itemCount: habits.length,
                    itemBuilder: (context, index) {
                      Habit habit = habits[index];
                      // Usa HabitCardWithHeatmap aqui para exibir o heatmap individual
                      // Mas SEM as características de texto
                      return HabitCardWithHeatmap(
                        habit: habit,
                        onHabitModified: _refreshDataAfterModification,
                        onCheckButtonPressed: (habitToRecord) {
                          if (habitToRecord.completionMethod == 'quantity' ||
                              habitToRecord.completionMethod == 'minutes') {
                            _showQuantityDialog(habitToRecord);
                          } else {
                            _recordHabitCompletion(
                              habitToRecord.id,
                              habitToRecord.completionMethod,
                            );
                          }
                        },
                        showDetails:
                            false, // NOVO: Passa false para ocultar os detalhes
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
