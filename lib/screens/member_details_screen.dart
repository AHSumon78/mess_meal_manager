// lib/screens/member_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/calculation_mode.dart';
import '../models/member.dart';
import '../models/meal_record.dart';
import '../models/payment.dart';
import '../services/billing_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class MemberDetailsScreen extends StatefulWidget {
  final Member member;
  const MemberDetailsScreen({super.key, required this.member});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class MemberSummary {
  final double totalCost;
  final double totalPaid;
  final double balance;
  final int totalBreakfast;
  final int totalLunch;
  final int totalDinner;

  int get totalMeals => totalBreakfast + totalLunch + totalDinner;

  MemberSummary({
    this.totalCost = 0,
    this.totalPaid = 0,
    this.balance = 0,
    this.totalBreakfast = 0,
    this.totalLunch = 0,
    this.totalDinner = 0,
  });
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  final dbService = DatabaseService();
  final settingsService = SettingsService();
  final _paymentController = TextEditingController();

  late Future<List<Payment>> _paymentsFuture;
  late Future<MemberSummary> _summaryFuture;
  late Future<List<MealRecord>> _mealHistoryFuture;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _paymentsFuture = dbService.getPaymentsForMemberInMonth(
        widget.member.id,
        _selectedMonth.year,
        _selectedMonth.month,
      );
      _summaryFuture = _calculateSummary();
      _mealHistoryFuture = dbService.getMealsForMemberInMonth(
        widget.member.id,
        _selectedMonth.year,
        _selectedMonth.month,
      );
    });
  }

  Future<MemberSummary> _calculateSummary() async {
    final settings = await settingsService.loadSettings();
    final monthlyMeals = await dbService.getMealsForMemberInMonth(
      widget.member.id,
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final monthlyPayments = await dbService.getPaymentsForMemberInMonth(
      widget.member.id,
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final allMonthlyMeals = await dbService.getMealsForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final monthlyExpenses = await dbService.getExpensesForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    int totalBreakfast = 0;
    int totalLunch = 0;
    int totalDinner = 0;

    for (var meal in monthlyMeals) {
      totalBreakfast += meal.breakfastCount;
      totalLunch += meal.lunchCount;
      totalDinner += meal.dinnerCount;
    }

    final totalCost = settings.mode == CalculationMode.expenseBased
        ? BillingService.calculateExpenseBasedCostByDate(
            settings,
            monthlyMeals,
            allMonthlyMeals,
            monthlyExpenses,
          )
        : BillingService.calculateMealCost(settings, monthlyMeals);

    double totalPaid = 0;
    for (var payment in monthlyPayments) {
      totalPaid += payment.amount;
    }
    final balance = totalPaid - totalCost;

    return MemberSummary(
      totalCost: totalCost,
      totalPaid: totalPaid,
      balance: balance,
      totalBreakfast: totalBreakfast,
      totalLunch: totalLunch,
      totalDinner: totalDinner,
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _refreshData();
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _refreshData();
  }

  //
  Future<void> _shareMemberReportAsPdf() async {
    final summary = await _summaryFuture;
    final meals = await _mealHistoryFuture;
    final payments = await _paymentsFuture;

    final doc = pw.Document();

    final fontData = await rootBundle.load(
      'assets/fonts/HindSiliguri-Regular.ttf',
    );
    final ttf = pw.Font.ttf(fontData);
    final pw.ThemeData theme = pw.ThemeData.withFont(base: ttf, bold: ttf);
    final monthName = DateFormat.yMMMM().format(_selectedMonth);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'সদেস্যর মািসক িরেপার্ট',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'নাম: ${widget.member.name}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.Text('মাস: $monthName', style: pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'আর্িথক সারাংশ'),

          // STEP 3: Update the PDF summary
          pw.Text(' • েমাট সকােলর িমল: ${summary.totalBreakfast}'),
          pw.Text(' • েমাট দুপুেরর িমল: ${summary.totalLunch}'),
          pw.Text(' • েমাট রােতর িমল: ${summary.totalDinner}'),
          pw.Divider(height: 10),
          pw.Text(' • েমাট খরচ: ৳${summary.totalCost.toStringAsFixed(2)}'),
          pw.Text(' • েমাট জমা: ৳${summary.totalPaid.toStringAsFixed(2)}'),
          pw.Text(
            ' • ব্যােলন্স: ৳${summary.balance.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),

          pw.Header(level: 1, text: 'িমেলর ই িতহাস'),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'সকাল', 'দুপুর', 'রাত'],
            data: meals
                .map(
                  (m) => [
                    DateFormat('dd/MM/yyyy').format(m.date),
                    m.breakfastCount.toString(),
                    m.lunchCount.toString(),
                    m.dinnerCount.toString(),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'জমার  ই িতহাস'),
          payments.isEmpty
              ? pw.Text('এই মােস  েকা েনা টাকা জমা হয় িন।')
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: payments
                      .map(
                        (p) => pw.Text(
                          ' • ${DateFormat('dd/MM/yyyy').format(p.date)} -> ৳${p.amount.toStringAsFixed(2)}',
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/report.pdf");
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          '${widget.member.name} আপনার $monthName মাসের Balance = ${summary.balance.toStringAsFixed(2)} ',
    );
  }

  Future<void> _showAddPaymentDialog() async {
    _paymentController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment'),
        content: TextField(
          controller: _paymentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_paymentController.text);
              if (amount != null && amount > 0) {
                DateTime paymentDate;
                final now = DateTime.now();
                if (_selectedMonth.year == now.year &&
                    _selectedMonth.month == now.month) {
                  paymentDate = DateTime(now.year, now.month, now.day);
                } else {
                  // THE CHANGE IS HERE: Use the first day of the selected month
                  paymentDate = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month,
                    1,
                  );
                }
                final newPayment = Payment(
                  id: const Uuid().v4(),
                  memberId: widget.member.id,
                  amount: amount,
                  date: paymentDate,
                );
                await dbService.addPayment(newPayment);
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Amount'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                DateTime paymentDate;
                final now = DateTime.now();
                if (_selectedMonth.year == now.year &&
                    _selectedMonth.month == now.month) {
                  paymentDate = now;
                } else {
                  // THE CHANGE IS HERE: Use the first day of the selected month
                  paymentDate = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month,
                    1,
                  );
                }
                final newPayment = Payment(
                  id: const Uuid().v4(),
                  memberId: widget.member.id,
                  amount: -amount,
                  date: paymentDate,
                );
                await dbService.addPayment(newPayment);
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _shareMemberReportAsPdf,
            tooltip: 'Share Report as PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goToPreviousMonth,
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM().format(_selectedMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _goToNextMonth,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<MemberSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final summary = snapshot.data ?? MemberSummary();
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Summary for ${DateFormat.yMMMM().format(_selectedMonth)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SummaryRow(
                        title: 'Total Breakfast:',
                        value: '${summary.totalBreakfast}',
                      ),
                      SummaryRow(
                        title: 'Total Lunch:',
                        value: '${summary.totalLunch}',
                      ),
                      SummaryRow(
                        title: 'Total Dinner:',
                        value: '${summary.totalDinner}',
                      ),
                      const Divider(),
                      SummaryRow(
                        title: 'Monthly Cost:',
                        value: '৳ ${summary.totalCost.toStringAsFixed(2)}',
                      ),
                      SummaryRow(
                        title: 'Monthly Paid:',
                        value: '৳ ${summary.totalPaid.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 20),
                      SummaryRow(
                        title: 'Monthly Balance:',
                        value: '৳ ${summary.balance.toStringAsFixed(2)}',
                        valueColor: summary.balance >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _showAddPaymentDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Payment'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton.icon(
                onPressed: _showWithdrawDialog,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Withdraw'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
          const Divider(height: 40),
          Text(
            'Meal History for ${DateFormat.yMMMM().format(_selectedMonth)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<MealRecord>>(
            future: _mealHistoryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No meals recorded this month.'),
                  ),
                );
              }
              final meals = snapshot.data!;
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: DataTable(
                  columnSpacing: 24.0,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'সকাল',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'দুপুর',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'রাত',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: meals
                      .map(
                        (meal) => DataRow(
                          cells: [
                            DataCell(
                              Text(DateFormat('dd/MM/yyyy').format(meal.date)),
                            ),
                            DataCell(Text(meal.breakfastCount.toString())),
                            DataCell(Text(meal.lunchCount.toString())),
                            DataCell(Text(meal.dinnerCount.toString())),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
          const Divider(height: 40),
          Text(
            'Payment History for ${DateFormat.yMMMM().format(_selectedMonth)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Payment>>(
            future: _paymentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No payments or withdrawals this month.'),
                  ),
                );
              }
              final payments = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  final isDeposit = payment.amount >= 0;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isDeposit
                            ? Icons.arrow_circle_up
                            : Icons.arrow_circle_down,
                        color: isDeposit ? Colors.green : Colors.red,
                        size: 30,
                      ),
                      title: Text(
                        '৳ ${payment.amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDeposit
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(payment.date),
                      ),
                      trailing: Text(
                        isDeposit ? 'Deposit' : 'Withdrawal',
                        style: TextStyle(
                          color: isDeposit ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const SummaryRow({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
