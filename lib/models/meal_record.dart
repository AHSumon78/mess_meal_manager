// lib/models/meal_record.dart
class MealRecord {
  final String id;
  final String memberId;
  final DateTime date;
  final int breakfastCount;
  final int lunchCount;
  final int dinnerCount;

  MealRecord({
    required this.id,
    required this.memberId,
    required this.date,
    this.breakfastCount = 0,
    this.lunchCount = 0,
    this.dinnerCount = 0,
  });

  int get totalMeals => breakfastCount + lunchCount + dinnerCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      // FIX: Save only the date part (YYYY-MM-DD)
      'date': date.toIso8601String().substring(0, 10),
      'breakfastCount': breakfastCount,
      'lunchCount': lunchCount,
      'dinnerCount': dinnerCount,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'],
      memberId: map['memberId'],
      date: DateTime.parse(map['date']),
      breakfastCount: map['breakfastCount'],
      lunchCount: map['lunchCount'],
      dinnerCount: map['dinnerCount'],
    );
  }
}
