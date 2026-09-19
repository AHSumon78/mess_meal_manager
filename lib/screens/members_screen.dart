// lib/screens/members_screen.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/a.dart';
import '../models/member.dart';
import '../services/database_service.dart';
import 'member_details_screen.dart';

// Enum to manage the view type
enum BalanceViewType { allTime, monthly }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final dbService = DatabaseService();
  late Future<List<MemberWithBalance>> _membersFuture;

  BalanceViewType _selectedView = BalanceViewType.monthly;
  DateTime _selectedMonth = DateTime.now();
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _refreshMemberList();
  }

  void _refreshMemberList() {
    setState(() {
      if (_selectedView == BalanceViewType.allTime) {
        _membersFuture = dbService.getAllMembersWithBalance();
      } else {
        _membersFuture = dbService.getAllMembersWithBalanceForMonth(
          _selectedMonth.year,
          _selectedMonth.month,
        );
      }
    });
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _selectedView = BalanceViewType.monthly;
      });
      _refreshMemberList();
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _refreshMemberList();
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _refreshMemberList();
  }

  // --- All your dialog functions (add, edit, delete) remain unchanged ---
  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Add New Member'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Enter member's name"),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newMember = Member(
                  id: const Uuid().v4(),
                  name: name,
                  joiningDate: DateTime.now(),
                );
                await dbService.insertMember(newMember);
                if (mounted) Navigator.of(context).pop();
                _refreshMemberList();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMemberDialog(Member member) async {
    final nameController = TextEditingController(text: member.name);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Edit Member Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Enter new name"),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Update'),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final updatedMember = Member(
                  id: member.id,
                  name: newName,
                  joiningDate: member.joiningDate,
                );
                await dbService.updateMember(updatedMember);
                if (mounted) Navigator.of(context).pop();
                _refreshMemberList();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog(
    String memberId,
    String memberName,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete "$memberName"? All associated meals and payments will also be deleted permanently.',
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
              await dbService.deleteMember(memberId);
              if (mounted) Navigator.of(context).pop();
              _refreshMemberList();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareMonthlyReportAsPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final membersData = await _membersFuture;

      // Filter members who have at least 1 meal in the selected month
      final activeMembers = membersData.where((m) => m.totalMeals > 0).toList();

      if (activeMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active members found for this month.'),
            ),
          );
        }
        setState(() => _isGeneratingPdf = false);
        return;
      }

      final doc = pw.Document();
      final fontDataRegular = await rootBundle.load(
        'assets/fonts/HindSiliguri-Regular.ttf',
      );
      final fontDataBold = await rootBundle.load(
        'assets/fonts/HindSiliguri-Bold.ttf',
      ); // নিশ্চিত করুন ফাইলের নামটি সঠিক

      // ২. দুটি আলাদা ফন্ট অবজেক্ট তৈরি করুন
      final fontRegular = pw.Font.ttf(fontDataRegular);
      final fontBold = pw.Font.ttf(fontDataBold);

      // ৩. দুটি ফন্ট ব্যবহার করে থিম তৈরি করুন
      final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);
      final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'মািসক সদস্য িরেপার্ট',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(monthName, style: pw.TextStyle(fontSize: 16)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.5),
                5: pw.FlexColumnWidth(1.5),
                6: pw.FlexColumnWidth(1.5),
              },
              children: [
                // --- Table Header Row (Always Bold) ---
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children:
                      [
                            'নাম',
                            'সকাল',
                            'দুপুর',
                            'রাত',
                            ' েমাট খরচ',
                            ' েমাট জমা',
                            'Balance',
                          ]
                          .map(
                            (header) => pw.Container(
                              alignment: pw.Alignment.center,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                header,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),

                // --- Data Rows with Alternating Font Weight ---
                ...activeMembers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final memberData = entry.value;

                  // Determine the font weight based on the row index
                  // Even rows (0, 2, 4...) will be normal, Odd rows (1, 3, 5...) will be bold
                  final fontWeight = (index % 2 == 0)
                      ? pw.FontWeight.normal
                      : pw.FontWeight.bold;

                  final totalPaid = memberData.balance + memberData.totalCost;

                  final rowData = [
                    memberData.member.name,
                    memberData.totalBreakfast.toString(),
                    memberData.totalLunch.toString(),
                    memberData.totalDinner.toString(),
                    memberData.totalCost.toStringAsFixed(2),
                    totalPaid.toStringAsFixed(2),
                    memberData.balance.toStringAsFixed(2),
                  ];

                  return pw.TableRow(
                    children: rowData
                        .map(
                          (cellData) => pw.Container(
                            alignment: pw.Alignment.center,
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              cellData,
                              style: pw.TextStyle(
                                fontWeight: fontWeight,
                              ), // Apply the alternating font weight
                            ),
                          ),
                        )
                        .toList(),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/monthly_report.pdf");
      await file.writeAsBytes(await doc.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Monthly Report for $monthName');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Members'),
        actions: [
          _isGeneratingPdf
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 95, 47, 47),
                      strokeWidth: 2.0,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _shareMonthlyReportAsPdf,
                  tooltip: 'Share Monthly Report',
                ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMemberList,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('All-Time Balance'),
                  selectedColor: Colors.teal.withOpacity(0.2),
                  selected: _selectedView == BalanceViewType.allTime,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedView = BalanceViewType.allTime);
                      _refreshMemberList();
                    }
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _goToPreviousMonth,
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _showMonthPicker,
                          child: Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: FutureBuilder<List<MemberWithBalance>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('An error occurred: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No members found. Add one!'),
                  );
                }

                final membersWithBalance = snapshot.data!;

                // --- NEW: Calculate the Net Balance ---
                final double netBalance = membersWithBalance.fold(
                  0.0,
                  (sum, item) => sum + item.balance,
                );
                final netBalanceColor = netBalance >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700;
                final cardTitle = _selectedView == BalanceViewType.allTime
                    ? 'Net All-Time Balance'
                    : 'Net Balance for ${DateFormat('MMMM').format(_selectedMonth)}';

                // --- UPDATED: Return a Column to hold the card and the list ---
                return Column(
                  children: [
                    // --- NEW: Summary Card for Net Balance ---
                    Card(
                      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),

                      child: ListTile(
                        title: Text(
                          cardTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          '৳ ${netBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: netBalanceColor,
                          ),
                        ),
                      ),
                    ),

                    // --- UPDATED: The list is now wrapped in an Expanded widget ---
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: membersWithBalance.length,
                        itemBuilder: (context, index) {
                          final item = membersWithBalance[index];
                          final balance = item.balance;
                          final balanceColor = balance >= 0
                              ? Colors.green
                              : Colors.red;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  item.member.name.isNotEmpty
                                      ? item.member.name[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                item.member.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Balance: ৳ ${balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: balanceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _showEditMemberDialog(item.member),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _showDeleteConfirmDialog(
                                      item.member.id,
                                      item.member.name,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemberDetailsScreen(
                                      member: item.member,
                                    ),
                                  ),
                                ).then((_) => _refreshMemberList());
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        tooltip: 'Add Member',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
