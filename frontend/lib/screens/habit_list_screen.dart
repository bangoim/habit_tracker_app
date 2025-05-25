import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/habit.dart'; // Importa o modelo Habit
import 'package:frontend/main.dart'; // Importa o main.dart para acessar HabitFormScreen

class HabitListScreen extends StatefulWidget {
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  late Future<List<Habit>> futureHabits;

  @override
  void initState() {
    super.initState();
    futureHabits = fetchHabits();
  }

  Future<List<Habit>> fetchHabits() async {
    final String apiUrl = 'http://10.0.2.2:5000/habits';
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

  Future<void> _recordHabitCompletion(
    int habitId,
    String completionMethod, {
    int? quantityCompleted,
  }) async {
    final String apiUrl = 'http://10.0.2.2:5000/habit_records';
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
        setState(() {
          futureHabits = fetchHabits();
        });
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
                      labelText: habit.completionMethod == 'quantity'
                          ? 'Quantidade realizada'
                          : 'Minutos realizados',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira um valor';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Por favor, insira um número válido';
                      }
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
              onPressed: () {
                Navigator.of(context).pop();
              },
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

  Future<void> _deleteHabit(int habitId) async {
    final String apiUrl = 'http://10.0.2.2:5000/habits/$habitId';
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
            'Tem certeza de que deseja excluir este hábito? Todos os registros relacionados serão apagados.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (confirmDelete == true) {
      try {
        final response = await http.delete(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hábito excluído com sucesso!')),
          );
          setState(() {
            futureHabits = fetchHabits();
          });
        } else if (response.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hábito não encontrado.')),
          );
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir hábito: ${errorData['error']}'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro de conexão ao excluir: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    // Cores de referência para o botão de checkmark (baseado na imagem (3).png)
    const checkButtonBackgroundColor = Color(0xFFEDE7F6); // Lilás bem claro (similar a Colors.deepPurple.shade50)
    final checkButtonIconColor = Colors.deepPurple.shade600; // Roxo escuro para o ícone

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Hábitos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                futureHabits = fetchHabits();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Habit>>(
        future: futureHabits,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum hábito cadastrado ainda.'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8.0, left: 8.0, right: 8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                Habit habit = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Bordas mais arredondadas
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nome do Hábito
                            Padding(
                              padding: const EdgeInsets.only(right: 56.0), // Espaço para o botão de check no canto superior direito
                              child: Text(
                                habit.name,
                                style: const TextStyle( // Estilo do título alterado
                                  fontSize: 22, // Tamanho da fonte aumentado
                                  fontWeight: FontWeight.bold, // Peso da fonte
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8), // Espaço entre título e informações

                            _buildTargetText(habit),
                            const SizedBox(height: 4),

                            if (habit.completionMethod == 'quantity' ||
                                habit.completionMethod == 'minutes')
                              Text(
                                'Progresso: ${habit.currentPeriodQuantity ?? 0} de ${habit.targetQuantity ?? 'N/A'} ${habit.completionMethod == 'minutes' ? 'min' : 'x'}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              )
                            else if (habit.countMethod == 'weekly' ||
                                habit.countMethod == 'monthly')
                              Text(
                                'Progresso: ${habit.currentPeriodDaysCompleted ?? 0} de ${habit.targetDaysPerWeek ?? 'N/A'} dias',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              )
                            else
                              const SizedBox.shrink(),
                            const SizedBox(height: 4),

                            Text(
                              'Streak: ${habit.currentStreak} dias',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 10), // Espaço para o menu no canto inferior esquerdo
                          ],
                        ),

                        // Botão de Checkmark (estilo FAB squircle no canto SUPERIOR direito)
                        Positioned(
                          top: 1, // Ajuste para alinhar com o topo do card, considerando o padding
                          right: 1, // Ajuste para alinhar com a direita do card
                          child: Material(
                            color: habit.isCompletedToday ? Colors.grey.shade300 : checkButtonBackgroundColor,
                            borderRadius: BorderRadius.circular(12.0), // Formato squircle
                            elevation: habit.isCompletedToday ? 0 : 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.0),
                              onTap: habit.isCompletedToday
                                  ? null
                                  : () {
                                      if (habit.completionMethod == 'quantity' ||
                                          habit.completionMethod == 'minutes') {
                                        _showQuantityDialog(habit);
                                      } else {
                                        _recordHabitCompletion(
                                            habit.id, habit.completionMethod);
                                      }
                                    },
                              child: Container(
                                width: 55, // Tamanho do botão
                                height: 55, // Tamanho do botão
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 26.0, // Tamanho do ícone
                                  color: habit.isCompletedToday ? Colors.grey.shade700 : checkButtonIconColor,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Menu de 3 Pontos (canto INFERIOR esquerdo)
                        Positioned(
                          bottom: 0, // Ajuste para o canto inferior
                          right: 4,   // Ajuste para "mais no canto"
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 26),
                            offset: const Offset(0, 30), // Desloca o menu para baixo para não cobrir o ícone
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        HabitFormScreen(habit: habit),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {
                                    futureHabits = fetchHabits();
                                  });
                                }
                              } else if (value == 'delete') {
                                _deleteHabit(habit.id);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Excluir'),
                                  ),
                                ],
                          ),
                        ),
                        // O círculo de status foi removido.
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HabitFormScreen(),
            ),
          );
          if (result == true) {
            setState(() {
              futureHabits = fetchHabits();
            });
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Adicionar novo hábito',
      ),
    );
  }
}
