// lib/screens/habit_list_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/habit.dart';
import '../models/category_model.dart';
import 'package:frontend/main.dart'; // Para HabitFormScreen

class HabitListScreen extends StatefulWidget {
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  Future<List<Habit>>? _futureDisplayedHabits; // Hábitos a serem exibidos (filtrados ou todos)
  List<CategoryModel> _categoriesInUseForFilter = []; // Apenas categorias com hábitos + "Todas" (implicitamente)
  int? _selectedCategoryIdFilter; // ID da categoria atualmente selecionada para filtro

  final String _baseUrl = 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    _loadAllHabitsAndSetupFilters(); // Carga inicial
  }

  // Carrega TODOS os hábitos para a exibição inicial e para popular os chips de filtro
  // com as categorias que estão realmente em uso.
  Future<void> _loadAllHabitsAndSetupFilters() async {
    if (!mounted) return;

    setState(() {
      _selectedCategoryIdFilter = null; // Seleciona "Todas" por padrão
      // Inicia a busca por todos os hábitos
      _futureDisplayedHabits = fetchHabits(categoryId: null);
    });

    try {
      // Aguarda a conclusão da busca de todos os hábitos
      final List<Habit>? allHabits = await _futureDisplayedHabits;

      if (allHabits != null && mounted) {
        // Extrai categorias únicas que estão realmente em uso
        Set<CategoryModel> usedCategoriesSet = {};
        for (var habit in allHabits) {
          for (var category in habit.categories) {
            usedCategoriesSet.add(category); // CategoryModel deve ter '==' e 'hashCode' implementados (baseado no ID)
          }
        }
        List<CategoryModel> sortedUsedCategories = usedCategoriesSet.toList();
        // Ordena as categorias por nome para consistência na UI
        sortedUsedCategories.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _categoriesInUseForFilter = sortedUsedCategories;
          // O FutureBuilder já está ouvindo _futureDisplayedHabits,
          // que foi iniciado com a busca de todos os hábitos.
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar e configurar filtros: $e')),
        );
      }
      // Define uma lista vazia ou trata o erro de outra forma se a carga inicial falhar
       if (mounted) {
        setState(() {
          _categoriesInUseForFilter = [];
          _futureDisplayedHabits = Future.value([]); // Evita que o FutureBuilder fique em loading infinito
        });
      }
    }
  }

  // Chamado quando um chip de filtro é selecionado ou um refresh específico do filtro é necessário
  void _filterHabitsBy({int? categoryId}) {
    if (!mounted) return;
    setState(() {
      _selectedCategoryIdFilter = categoryId;
      _futureDisplayedHabits = fetchHabits(categoryId: categoryId);
    });
    // _categoriesInUseForFilter não é alterada aqui, pois ela reflete todas as categorias
    // em uso em todos os hábitos. Ela só é recalculada em _loadAllHabitsAndSetupFilters.
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
      // Se a exceção for do throw acima, ela será propagada.
      // Se for um erro de conexão (ex: SocketException), esta mensagem será usada.
      throw Exception('Falha ao conectar com o backend: $e');
    }
  }

  // Atualize as chamadas de recarregamento nos métodos auxiliares
  Future<void> _refreshDataAfterModification() async {
    // Esta função será chamada após adicionar, editar, deletar ou registrar um hábito.
    // Ela recarrega todos os hábitos e reconfigura os filtros.
    await _loadAllHabitsAndSetupFilters();
  }


  @override
  Widget build(BuildContext context) {
    const checkButtonBackgroundColor = Color(0xFFEDE7F6);
    final checkButtonIconColor = Colors.deepPurple.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Hábitos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllHabitsAndSetupFilters, // Refresh geral
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de Categoria com Chips
          // Mostra a barra de filtro se houver categorias em uso ou se a carga inicial já aconteceu
          // (_futureDisplayedHabits != null indica que a primeira tentativa de carga ocorreu)
          if (_futureDisplayedHabits != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        label: const Text('Todas'),
                        selected: _selectedCategoryIdFilter == null,
                        onSelected: (bool selected) {
                          // Ao selecionar "Todas", aplicamos o filtro para null
                          _filterHabitsBy(categoryId: null);
                        },
                        checkmarkColor: _selectedCategoryIdFilter == null ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                        selectedColor: _selectedCategoryIdFilter == null ? Theme.of(context).colorScheme.primaryContainer : null,
                        labelStyle: _selectedCategoryIdFilter == null
                            ? TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)
                            : null,
                      ),
                    ),
                    ..._categoriesInUseForFilter.map((category) { // Usa _categoriesInUseForFilter
                      bool isSelected = _selectedCategoryIdFilter == category.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            // Se o chip já está selecionado e é clicado de novo,
                            // ou se um chip não selecionado é marcado como 'não selecionado' (raro),
                            // voltamos para "Todas". Caso contrário, aplicamos o filtro da categoria.
                            _filterHabitsBy(categoryId: selected ? category.id : null);
                          },
                          checkmarkColor: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                          selectedColor: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                           labelStyle: isSelected
                            ? TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)
                            : null,
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
                      child: Text('Erro ao carregar hábitos: ${snapshot.error}\Por favor, tente atualizar.'),
                    )
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum hábito encontrado.'));
                } else {
                  final habits = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 0, left: 8.0, right: 8.0),
                    itemCount: habits.length,
                    itemBuilder: (context, index) {
                      Habit habit = habits[index];
                      return Card(
                         margin: const EdgeInsets.symmetric(vertical: 6.0),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         elevation: 2,
                        child: Padding(
                           padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
                           child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Padding(
                                    padding: const EdgeInsets.only(right: 56.0),
                                    child: Text(habit.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(height: 4),
                                  if (habit.categories.isNotEmpty)
                                    Wrap(
                                      spacing: 4.0,
                                      runSpacing: 0.0,
                                      children: habit.categories.map((cat) => Chip(
                                        label: Text(cat.name),
                                        padding: EdgeInsets.zero,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 6.0),
                                        visualDensity: VisualDensity.compact,
                                        labelStyle: const TextStyle(fontSize: 10),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                                        side: BorderSide.none,
                                      )).toList(),
                                    ),
                                  const SizedBox(height: 8),
                                  _buildTargetText(habit),
                                  const SizedBox(height: 4),
                                  if (habit.completionMethod == 'quantity' || habit.completionMethod == 'minutes')
                                    Text('Progresso: ${habit.currentPeriodQuantity ?? 0} de ${habit.targetQuantity ?? 'N/A'} ${habit.completionMethod == 'minutes' ? 'min' : 'x'}', style: TextStyle(fontSize: 14, color: Colors.grey[700]))
                                  else if (habit.countMethod == 'weekly' || habit.countMethod == 'monthly')
                                    Text('Progresso: ${habit.currentPeriodDaysCompleted ?? 0} de ${habit.targetDaysPerWeek ?? 'N/A'} dias', style: TextStyle(fontSize: 14, color: Colors.grey[700]))
                                  else
                                    const SizedBox.shrink(),
                                  const SizedBox(height: 4),
                                  Text('Streak: ${habit.currentStreak} dias', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                  const SizedBox(height: 10),
                                ],
                              ),
                               Positioned(
                                top: 1, right: 1,
                                child: Material(
                                  color: habit.isCompletedToday ? Colors.grey.shade300 : checkButtonBackgroundColor,
                                  borderRadius: BorderRadius.circular(12.0),
                                  elevation: habit.isCompletedToday ? 0 : 2,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12.0),
                                    onTap: habit.isCompletedToday ? null : () {
                                      if (habit.completionMethod == 'quantity' || habit.completionMethod == 'minutes') {
                                        _showQuantityDialog(habit);
                                      } else {
                                        _recordHabitCompletion(habit.id, habit.completionMethod);
                                      }
                                    },
                                    child: Container(
                                      width: 55, height: 55, alignment: Alignment.center,
                                      child: Icon(Icons.check_rounded, size: 26.0, color: habit.isCompletedToday ? Colors.grey.shade700 : checkButtonIconColor),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 4,
                                child: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 26),
                                  offset: const Offset(0, 30),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => HabitFormScreen(habit: habit)),
                                      );
                                      if (result == true && mounted) {
                                        _refreshDataAfterModification(); // Atualiza tudo
                                      }
                                    } else if (value == 'delete') {
                                      _deleteHabit(habit.id);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                                    const PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
                                  ],
                                ),
                              ),
                            ],
                           ),
                        )
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitFormScreen()),
          );
          if (result == true && mounted) {
            _refreshDataAfterModification(); // Atualiza tudo
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Adicionar novo hábito',
      ),
    );
  }

  // Métodos auxiliares atualizados para chamar _refreshDataAfterModification
  Future<void> _recordHabitCompletion(int habitId, String completionMethod, {int? quantityCompleted}) async {
    final String apiUrl = '$_baseUrl/habit_records';
    final String recordDate = DateTime.now().toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'habit_id': habitId, 'record_date': recordDate, 'quantity_completed': quantityCompleted,
        }),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hábito registrado com sucesso!')));
        _refreshDataAfterModification(); // ATUALIZADO
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hábito já registrado para hoje!')));
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao registrar hábito: ${errorData['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de conexão ao registrar: $e')));
    }
  }

  Future<void> _showQuantityDialog(Habit habit) async {
    TextEditingController quantityController = TextEditingController();
    final formKeyDialog = GlobalKey<FormState>();
    return showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Registrar ${habit.name}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKeyDialog,
              child: ListBody(children: <Widget>[
                TextFormField(
                  controller: quantityController, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: habit.completionMethod == 'quantity' ? 'Quantidade realizada' : 'Minutos realizados'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Por favor, insira um valor';
                    if (int.tryParse(value) == null) return 'Por favor, insira um número válido';
                    return null;
                  },
                ),
              ]),
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Registrar'),
              onPressed: () {
                if (formKeyDialog.currentState!.validate()) {
                  _recordHabitCompletion(habit.id, habit.completionMethod, quantityCompleted: int.parse(quantityController.text));
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteHabit(int habitId) async {
    final String apiUrl = '$_baseUrl/habits/$habitId';
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza de que deseja excluir este hábito? Todos os registros relacionados serão apagados.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmDelete == true && mounted) { // Adicionado 'mounted' check
      try {
        final response = await http.delete(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hábito excluído com sucesso!')));
           _refreshDataAfterModification(); // ATUALIZADO
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir hábito: ${response.body}')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de conexão ao excluir: $e')));
      }
    }
  }

  Widget _buildTargetText(Habit habit) {
    if (habit.targetQuantity != null) {
      return Text(
        'Alvo: ${habit.targetQuantity} ${habit.completionMethod == 'minutes' ? 'min' : 'x'}',
         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      );
    } else if (habit.targetDaysPerWeek != null) {
      return Text('Alvo: ${habit.targetDaysPerWeek} dias no período',
         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      );
    }
    return const SizedBox.shrink();
  }
}
