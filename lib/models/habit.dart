import 'dart:convert';

class Habit {
  Habit({
    required this.id,
    required this.title,
    required this.targetDescription,
    this.completedToday = false,
    this.streak = 0,
  });

  final String id;
  final String title;
  final String targetDescription;
  bool completedToday;
  int streak;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'targetDescription': targetDescription,
        'completedToday': completedToday,
        'streak': streak,
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as String,
        title: map['title'] as String,
        targetDescription: map['targetDescription'] as String,
        completedToday: map['completedToday'] as bool? ?? false,
        streak: map['streak'] as int? ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  factory Habit.fromJson(String source) =>
      Habit.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
