// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';
import '../models/calculation_mode.dart';
import '../services/billing_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

// Helper class for the new table data
class DailyMemberMeal {
  final String memberName;
  final int breakfast;
  final int lunch;
  final int dinner;

  DailyMemberMeal({
    required this.memberName,
    this.breakfast = 0,
    this.lunch = 0,
    this.dinner = 0,
  });
}

// HomeSummary class is updated to hold the list for the new table
class HomeSummary {
  final Map<String, int> dailyMeals;
  final double openingBalance;
  final double todaysBill;
  final double paidToday;
  final double closingBalance;
  final List<DailyMemberMeal> memberMeals; // New data for the table

  HomeSummary({
    required this.dailyMeals,
    this.openingBalance = 0.0,
    this.todaysBill = 0.0,
    this.paidToday = 0.0,
    this.closingBalance = 0.0,
    required this.memberMeals,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbService = DatabaseService();
  final settingsService = SettingsService();
  late DateTime _selectedDate;
  late Future<HomeSummary> _summaryFuture;
  HomeSummary? _latestSummary;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadDataForDate();
  }

  void _loadDataForDate() {
    setState(() {
      _summaryFuture = _calculateHomeSummary();
    });
  }

  Future<HomeSummary> _calculateHomeSummary() async {
    final settings = await settingsService.loadSettings();
    final dateString = _selectedDate.toIso8601String().substring(0, 10);
    final yesterdayString = _selectedDate
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    // Fetch all necessary data
    final dailyMealsSummary = await dbService.getTodaysMealSummary(dateString);
    final mealsUpToYesterday = await dbService.getAllMealsUpTo(yesterdayString);
    final expensesUpToYesterday = await dbService.getAllExpensesUpTo(
      yesterdayString,
    );
    final expensesForToday = await dbService.getExpensesForDate(dateString);

    // --- Data fetch for the new table ---
    final allMembers = await dbService.getAllMembers();
    final mealsForDate = await dbService.getMealsForDate(dateString);

    final totalBillUpToYesterday = settings.mode == CalculationMode.expenseBased
        ? BillingService.calculateExpenseBasedCostByDate(
            settings,
            mealsUpToYesterday,
            mealsUpToYesterday,
            expensesUpToYesterday,
          )
        : BillingService.calculateMealCost(settings, mealsUpToYesterday);
    final totalPaidUpToYesterday = expensesUpToYesterday.fold(
      0.0,
      (sum, e) => sum + e.amount,
    );
    final openingBalance = totalPaidUpToYesterday - totalBillUpToYesterday;
    final expensesForMonth = await dbService.getExpensesForMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    final mealsForMonth = await dbService.getMealsForMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    final todaysBill = settings.mode == CalculationMode.expenseBased
        ? BillingService.calculateExpenseBasedCostByDate(
            settings,
            mealsForDate,
            mealsForMonth,
            expensesForMonth,
          )
        : BillingService.calculateMealCost(settings, mealsForDate);
    final paidToday = expensesForToday.fold(0.0, (sum, e) => sum + e.amount);
    final closingBalance = openingBalance - todaysBill + paidToday;

    // --- Logic to prepare data for the new table ---
    final List<DailyMemberMeal> memberMealList = [];
    final mealMap = {for (var meal in mealsForDate) meal.memberId: meal};
    for (var member in allMembers) {
      final mealRecord = mealMap[member.id];
      memberMealList.add(
        DailyMemberMeal(
          memberName: member.name,
          breakfast: mealRecord?.breakfastCount ?? 0,
          lunch: mealRecord?.lunchCount ?? 0,
          dinner: mealRecord?.dinnerCount ?? 0,
        ),
      );
    }

    return HomeSummary(
      dailyMeals: dailyMealsSummary,
      openingBalance: openingBalance,
      todaysBill: todaysBill,
      paidToday: paidToday,
      closingBalance: closingBalance,
      memberMeals: memberMealList, // Pass the new list
    );
  }

  // Your share function remains unchanged, as you requested
  void _shareSummary() {
    if (_latestSummary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data not loaded yet. Please wait.')),
      );
      return;
    }
    final summary = _latestSummary!;
    final dateString = DateFormat('EEEE, d MMMM y').format(_selectedDate);

    String previousDuesText;
    if (summary.openingBalance >= 0) {
      previousDuesText =
          '• আমি আগের পাব: ৳${summary.openingBalance.toStringAsFixed(2)}';
    } else {
      previousDuesText =
          '• আপনি আগের পাবেন: ৳${summary.openingBalance.abs().toStringAsFixed(2)}';
    }

    String currentBalanceText;
    if (summary.closingBalance >= 0) {
      currentBalanceText =
          '• বর্তমান ব্যালেন্স: ৳${summary.closingBalance.toStringAsFixed(2)} (আমি পাবো)';
    } else {
      currentBalanceText =
          '• বর্তমান ব্যালেন্স: ৳${summary.closingBalance.abs().toStringAsFixed(2)} (আপনি পাবেন)';
    }

    final breakfast = summary.dailyMeals['breakfast'] ?? 0;
    final lunch = summary.dailyMeals['lunch'] ?? 0;
    final dinner = summary.dailyMeals['dinner'] ?? 0;

    final String reportText =
        """
** মিলের হিসাব($dateString) **
------------------------------------
আজকের মিল:
• সকাল: $breakfast টি
• দুপুর: $lunch টি
• রাত: $dinner টি
আজকের হিসাব = ${summary.todaysBill.toStringAsFixed(2)}
------------------------------------
আজ পর্যন্ত হিসাব:
$previousDuesText
• আজকে দিলাম: ৳${summary.paidToday.toStringAsFixed(2)}
$currentBalanceText
""";
    Share.share(reportText);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDataForDate();
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadDataForDate();
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadDataForDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Summary"),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareSummary),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataForDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goToPreviousDay,
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _goToNextDay,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<HomeSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final summary = snapshot.data!;
                _latestSummary = summary;
                final dailyMeals = summary.dailyMeals;
                final openingBalanceText =
                    '৳${summary.openingBalance.abs().toStringAsFixed(2)} ${summary.openingBalance >= 0 ? '(Manager পাবে)' : '(Supplier পাবে)'}';
                final closingBalanceText =
                    '৳${summary.closingBalance.abs().toStringAsFixed(2)} ${summary.closingBalance >= 0 ? '(Manager পাবে)' : '(Supplier পাবে)'}';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            LedgerRow(
                              title: 'Opening Balance:',
                              value: openingBalanceText,
                              color: summary.openingBalance >= 0
                                  ? Colors.blue
                                  : Colors.red,
                            ),
                            LedgerRow(
                              title: '(+) Today\'s Bill:',
                              value:
                                  '৳ ${summary.todaysBill.toStringAsFixed(2)}',
                              color: Colors.orange,
                            ),
                            LedgerRow(
                              title: '(-) Paid Today:',
                              value:
                                  '৳ ${summary.paidToday.toStringAsFixed(2)}',
                              color: Colors.green,
                            ),
                            const Divider(),
                            LedgerRow(
                              title: 'Closing Balance =',
                              value: closingBalanceText,
                              color: summary.closingBalance >= 0
                                  ? Colors.blue
                                  : Colors.red,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      'Daily Meal Count for ${DateFormat.yMMMd().format(_selectedDate)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SummaryCard(
                      title: 'সকাল (Breakfast)',
                      count: dailyMeals['breakfast'] ?? 0,
                      color: Colors.orange.shade100,
                    ),
                    const SizedBox(height: 8),
                    SummaryCard(
                      title: 'দুপুর (Lunch)',
                      count: dailyMeals['lunch'] ?? 0,
                      color: Colors.green.shade100,
                    ),
                    const SizedBox(height: 8),
                    SummaryCard(
                      title: 'রাত (Dinner)',
                      count: dailyMeals['dinner'] ?? 0,
                      color: Colors.blue.shade100,
                    ),

                    // --- THIS IS THE NEWLY ADDED TABLE ---
                    const Divider(height: 30),
                    const Text(
                      'Daily Member Meals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: DataTable(
                        columnSpacing: 16.0,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Member',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'B',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'L',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'D',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: summary.memberMeals
                            .where(
                              (m) =>
                                  m.breakfast > 0 ||
                                  m.lunch > 0 ||
                                  m.dinner > 0,
                            )
                            .map(
                              (memberMeal) => DataRow(
                                cells: [
                                  DataCell(Text(memberMeal.memberName)),
                                  DataCell(
                                    Text(memberMeal.breakfast.toString()),
                                  ),
                                  DataCell(Text(memberMeal.lunch.toString())),
                                  DataCell(Text(memberMeal.dinner.toString())),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LedgerRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final bool isBold;

  const LedgerRow({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
