// lib/screens/manager_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../services/database_service.dart';

class ManagerLedgerScreen extends StatefulWidget {
  const ManagerLedgerScreen({super.key});

  @override
  State<ManagerLedgerScreen> createState() => _ManagerLedgerScreenState();
}

class _ManagerLedgerScreenState extends State<ManagerLedgerScreen> {
  final dbService = DatabaseService();
  late Future<List<dynamic>> _dataFuture;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = Future.wait([
        dbService.getPaymentsForMonth(
          _selectedMonth.year,
          _selectedMonth.month,
        ),
        dbService.getExpensesForMonth(
          _selectedMonth.year,
          _selectedMonth.month,
        ),
      ]);
    });
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

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
      _refreshData();
    }
  }

  Future<void> _showAddExpenseDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    var expenseDate = DateTime.now();
    if (_selectedMonth.year != expenseDate.year ||
        _selectedMonth.month != expenseDate.month) {
      expenseDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Expense Date'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(expenseDate),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expenseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          expenseDate = picked;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (e.g., Bazar)',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    final description = descriptionController.text.trim();
                    if (amount != null && amount > 0) {
                      final newExpense = Expense(
                        id: const Uuid().v4(),
                        date: expenseDate,
                        amount: amount,
                        description: description,
                      );
                      await dbService.insertExpense(newExpense);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      _selectedMonth = DateTime(
                        expenseDate.year,
                        expenseDate.month,
                      );
                      _refreshData();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteExpenseConfirmDialog(Expense expense) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete the expense for "${expense.description}" (৳${expense.amount})?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                await dbService.deleteExpense(expense.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _refreshData();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager's Ledger"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousMonth,
                ),
                TextButton(
                  onPressed: () => _selectMonth(context),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
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
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No data found.'));
                }

                final monthlyPayments = snapshot.data![0] as List<Payment>;
                final monthlyExpenses = snapshot.data![1] as List<Expense>;

                final totalIncome = monthlyPayments
                    .where((p) => p.amount > 0)
                    .fold(0.0, (sum, p) => sum + p.amount);
                final totalWithdrawals = monthlyPayments
                    .where((p) => p.amount < 0)
                    .fold(0.0, (sum, p) => sum + p.amount.abs());
                final netCollectedFund = totalIncome - totalWithdrawals;
                final totalExpenses = monthlyExpenses.fold(
                  0.0,
                  (sum, e) => sum + e.amount,
                );
                final cashInHand = netCollectedFund - totalExpenses;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Overview for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SummaryRow(
                              title: 'Total Deposits:',
                              value: '৳ ${totalIncome.toStringAsFixed(2)}',
                              color: Colors.green,
                            ),
                            SummaryRow(
                              title: '(-) Total Withdrawals:',
                              value: '৳ ${totalWithdrawals.toStringAsFixed(2)}',
                              color: Colors.orange,
                            ),
                            const Divider(),
                            SummaryRow(
                              title: '= Net Collected Fund:',
                              value: '৳ ${netCollectedFund.toStringAsFixed(2)}',
                              isBold: true,
                            ),
                            const SizedBox(height: 10),
                            SummaryRow(
                              title: '(-) Total Expenses:',
                              value: '৳ ${totalExpenses.toStringAsFixed(2)}',
                              color: Colors.red,
                            ),
                            const Divider(),
                            SummaryRow(
                              title: '= Cash in Hand:',
                              value: '৳ ${cashInHand.toStringAsFixed(2)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showAddExpenseDialog,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add New Expense'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const Divider(height: 40),
                    Text(
                      'Expense History for ${DateFormat('MMMM').format(_selectedMonth)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (monthlyExpenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text('No expenses recorded for this month.'),
                        ),
                      ),
                    ...monthlyExpenses.map(
                      (expense) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.shopping_cart,
                            color: Colors.blueGrey,
                          ),
                          title: Text(expense.description),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(expense.date),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '৳ ${expense.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () =>
                                    _showDeleteExpenseConfirmDialog(expense),
                              ),
                            ],
                          ),
                        ),
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

class SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final bool isBold;

  const SummaryRow({
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
