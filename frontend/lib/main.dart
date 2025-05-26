// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart'
    as http; // Necessário para OverallProgressScreen
import 'dart:convert'; // Necessário para OverallProgressScreen
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart'; // Necessário para OverallProgressScreen

// Importe as telas para as abas
import 'package:frontend/screens/habit_list_screen.dart'; // Aba 1: Meus Hábitos (apenas lista e edição)
import 'package:frontend/screens/habit_progress_list_screen.dart'; // NOVO: Aba 2: Progresso dos Hábitos (com heatmaps individuais)
import 'package:frontend/screens/habit_form_screen.dart'; // Importe HabitFormScreen para o FAB

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      theme: ThemeData(
        // Removendo primarySwatch e usando ColorScheme.fromSeed para Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, // Changed to Teal for a more vibrant base
          brightness: Brightness.light, // Explicitly set to light mode
        ),
        useMaterial3: true,
        // Configurações globais para AppBar
        appBarTheme: AppBarTheme(
          backgroundColor:
              Colors.teal.shade400, // Matching AppBar with seed color
          foregroundColor: Colors.white, // White text and icons on AppBar
          elevation: 0, // Sem sombra na AppBar
          centerTitle: true, // Centraliza o título
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// Classe OverallProgressScreen (mantida e movida implicitamente para cá para simplificar)
// para o heatmap geral, será acessada da MainScreen como uma das abas.
class OverallProgressScreen extends StatefulWidget {
  const OverallProgressScreen({super.key});

  @override
  State<OverallProgressScreen> createState() => _OverallProgressScreenState();
}

class _OverallProgressScreenState extends State<OverallProgressScreen> {
  final String _baseUrl =
      'http://10.0.2.2:5000'; // Ajuste este IP se necessário
  Map<DateTime, int> _overallDatasets = {}; // Dataset para o heatmap geral
  bool _isLoadingOverallProgress = true;
  String? _overallErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOverallProgressData();
  }

  Future<void> _fetchOverallProgressData() async {
    setState(() {
      _isLoadingOverallProgress = true;
      _overallErrorMessage = null;
    });

    try {
      final DateTime today = DateTime.now();
      // Limite do heatmap para os últimos 12 meses (1 ano) para a visão geral
      final DateTime oneYearAgo = DateTime(
        today.year - 1,
        today.month,
        today.day,
      );

      final String apiUrl =
          '$_baseUrl/all_habit_records?' +
          'start_date=${oneYearAgo.toIso8601String().split('T')[0]}&' +
          'end_date=${today.toIso8601String().split('T')[0]}';

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        Map<DateTime, int> aggregatedDatasets = {};

        // Agregando os dados de todos os hábitos por dia
        for (var json in jsonList) {
          // Note: HabitRecord e Habit não são diretamente usados aqui, mas os imports ainda são necessários
          // para o contexto geral do projeto.
          DateTime recordDate = DateTime.parse(json['record_date'] as String);
          DateTime normalizedDate = DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
          );
          int quantity =
              json['quantity_completed'] as int? ??
              1; // 1 para booleanos, ou a quantidade

          aggregatedDatasets[normalizedDate] =
              (aggregatedDatasets[normalizedDate] ?? 0) + quantity;
        }

        if (mounted) {
          setState(() {
            _overallDatasets = aggregatedDatasets;
            _isLoadingOverallProgress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _overallErrorMessage =
                'Falha ao carregar progresso geral: ${response.statusCode} - ${response.body}';
            _isLoadingOverallProgress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _overallErrorMessage =
              'Erro de conexão ao carregar progresso geral: $e';
          _isLoadingOverallProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cores para o heatmap (reutilizadas da HabitHeatmapScreen)
    // Manteremos essas cores do heatmap, pois elas se referem à intensidade e são independentes do tema principal
    Color githubLightGreen = Colors.green.shade200;
    Color githubMediumGreen = Colors.green.shade500;
    Color githubDarkGreen = Colors.green.shade800;
    Color githubVeryDarkGreen = Colors.green.shade900;
    Color defaultDayColor =
        Colors
            .grey
            .shade300; // Alterado para um cinza mais claro para combinar com o tema claro

    final DateTime heatmapStartDate = DateTime(
      DateTime.now().year - 1,
      DateTime.now().month, // Mês atual do ano anterior
      DateTime.now().day,
    );
    final DateTime heatmapEndDate = DateTime.now();

    return Scaffold(
      backgroundColor:
          Theme.of(
            context,
          ).colorScheme.surface, // Usar a cor de superfície do tema
      appBar: AppBar(
        title: const Text('Progresso Geral'),
        // As cores do AppBar agora vêm do ThemeData.appBarTheme
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ), // Cor do ícone
            onPressed: _fetchOverallProgressData,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visão Geral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    // Cor do texto principal agora vem do tema
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context)
                            .colorScheme
                            .surfaceVariant, // Usar surfaceVariant para o container
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total de Registros',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _overallDatasets.values
                            .fold(0, (sum, element) => sum + element)
                            .toString(), // Soma todos os registros como um placeholder
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Atividade Diária (Todos os Hábitos)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child:
                _isLoadingOverallProgress
                    ? const Center(child: CircularProgressIndicator())
                    : _overallErrorMessage != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _overallErrorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      child: HeatMap(
                        startDate: heatmapStartDate,
                        endDate: heatmapEndDate,
                        datasets: _overallDatasets,
                        colorsets: {
                          1: githubLightGreen,
                          2: githubMediumGreen,
                          4: githubDarkGreen,
                          6: githubVeryDarkGreen,
                        },
                        defaultColor: defaultDayColor,
                        textColor:
                            Colors
                                .black87, // Alterado para texto mais escuro no heatmap
                        size: 14,
                        margin: const EdgeInsets.all(2),
                        borderRadius: 2,
                        scrollable: true,
                        showText: false,
                        showColorTip: true,
                        colorTipHelper: const [
                          Text(
                            'Nenhum',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Pouco',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Médio',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Muito',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Mais',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        onClick: (date) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Dia: ${date.toLocal().toString().split(' ')[0]}, Atividade Total: ${_overallDatasets[date] ?? 0}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// [MODIFICADO] MainScreen para gerenciar as 2 abas e o FAB
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Índice da aba selecionada

  // Lista de widgets para cada aba
  static final List<Widget> _widgetOptions = <Widget>[
    const HabitListScreen(), // Aba 1: Meus Hábitos
    const HabitProgressListScreen(), // Aba 2: Progresso
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(
          _selectedIndex,
        ), // Exibe a tela da aba selecionada
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Meus Hábitos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progresso',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor:
            Theme.of(
              context,
            ).colorScheme.primary, // Usar a cor primária do tema
        onTap: _onItemTapped,
        backgroundColor:
            Theme.of(context)
                .colorScheme
                .surfaceVariant, // Usar a cor de superfície do tema para o fundo da barra
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant
            .withOpacity(0.7), // Ícones não selecionados em um tom mais escuro
        type:
            BottomNavigationBarType
                .fixed, // Garante que os rótulos sempre apareçam
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitFormScreen()),
          );
          // Opcional: Se a tela de formulário retornar 'true', recarregar a lista de hábitos
          if (result == true && _selectedIndex == 0) {
            // Se estiver na aba "Meus Hábitos", force o refresh
            // Isso pode ser feito de várias formas, a mais simples é reconstruir o widget.
            // Para um refresh mais robusto, você precisaria de um Provider ou similar.
            setState(() {
              // Simplesmente reconstruir a aba para forçar o FutureBuilder a recarregar
              // Nota: Em um app maior, um State Management como Provider ou Riverpod
              // seria mais adequado para notificar a HabitListScreen a recarregar seus dados.
              // Para este exemplo, basta que a MainScreen se reconstrua.
            });
          } else if (result == true && _selectedIndex == 1) {
            setState(() {
              // Similarmente, reconstruir a aba de progresso se estiver nela
            });
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary, // Cor do FAB
        foregroundColor:
            Theme.of(context).colorScheme.onPrimary, // Cor do ícone no FAB
        shape: RoundedRectangleBorder(
          // Forma do FAB, exemplo como na imagem
          borderRadius: BorderRadius.circular(
            16.0,
          ), // Ajuste o raio para a forma desejada
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation
              .endFloat, // Posição do FAB agora na lateral
    );
  }
}
