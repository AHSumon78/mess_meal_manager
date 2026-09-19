// lib/models/a.dart
import 'member.dart';

class MemberWithBalance {
  final Member member;
  final double balance;
  final double totalCost;
  final DateTime? lastPaymentDate;

  // Meal counts
  final int totalBreakfast;
  final int totalLunch;
  final int totalDinner;

  // Getter to calculate total meals
  int get totalMeals => totalBreakfast + totalLunch + totalDinner;

  MemberWithBalance({
    required this.member,
    required this.balance,
    this.totalCost = 0,
    // Optional params
    this.lastPaymentDate,
    this.totalBreakfast = 0,
    this.totalLunch = 0,
    this.totalDinner = 0,
  });
}
