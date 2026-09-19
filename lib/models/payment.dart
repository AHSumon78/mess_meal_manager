// lib/models/payment.dart
class Payment {
  final String id;
  final String memberId; // Which member made the payment
  final double amount; // How much was paid
  final DateTime date; // When it was paid

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
  });

  // toMap and fromMap methods for sqflite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      memberId: map['memberId'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
    );
  }
}
