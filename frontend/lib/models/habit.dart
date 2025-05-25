class Habit {
  final int id;
  final String name;
  final String? description;
  final String countMethod;
  final String completionMethod;
  final int? targetQuantity;
  final int? targetDaysPerWeek;
  final String createdAt;
  final bool isCompletedToday;
  final String? lastCompletedDate;
  final int? currentPeriodQuantity;
  final int? currentPeriodDaysCompleted;
  final int currentStreak; // << ESTE CAMPO ESTAVA FALTANDO OU INCORRETO AQUI

  Habit({
    required this.id,
    required this.name,
    this.description,
    required this.countMethod,
    required this.completionMethod,
    this.targetQuantity,
    this.targetDaysPerWeek,
    required this.createdAt,
    required this.isCompletedToday,
    this.lastCompletedDate,
    this.currentPeriodQuantity,
    this.currentPeriodDaysCompleted,
    required this.currentStreak, // << E AQUI NO CONSTRUTOR
  });

  // Construtor de fábrica para criar uma instância de Habit a partir de um mapa JSON
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as int,
      name: json['name'],
      description: json['description'],
      countMethod: json['count_method'],
      completionMethod: json['completion_method'],

      // Converte para int com segurança, pode ser nulo se não houver valor ou for inválido
      targetQuantity: int.tryParse(json['target_quantity']?.toString() ?? ''),
      targetDaysPerWeek: int.tryParse(
        json['target_days_per_week']?.toString() ?? '',
      ),

      createdAt: json['created_at'],
      isCompletedToday: json['is_completed_today'] as bool,

      lastCompletedDate: json['last_completed_date'],

      // Converte para int com segurança, pode ser nulo
      currentPeriodQuantity: int.tryParse(
        json['current_period_quantity']?.toString() ?? '',
      ),
      currentPeriodDaysCompleted: int.tryParse(
        json['current_period_days_completed']?.toString() ?? '',
      ),
      currentStreak:
          json['current_streak'] as int, // << E AQUI NA FÁBRICA fromJson
    );
  }
}
