// lib/models/expense.dart
class Expense {
  final String id;
  final DateTime date;
  final double amount;
  final String description;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().substring(0, 10),
      'amount': amount,
      'description': description,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'],
      description: map['description'],
    );
  }
}
