import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'inventory_calculation.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class MDMReportsPage extends StatefulWidget {
  const MDMReportsPage({super.key});

  @override
  State<MDMReportsPage> createState() => _MDMReportsPageState();
}

class _MDMReportsPageState extends State<MDMReportsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> reports = [];
  List<Map<String, dynamic>> filteredReports = [];
  List<Map<String, dynamic>> menus = [];
  bool isLoading = false;
  String filterType = 'All';
  DateTime? selectedDate;
  String? selectedMonth;
  int selectedYear = DateTime.now().year;
  String? errorMessage;
  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final reportsResult = await _apiService.getAllReports();
      final menusData = await _apiService.getAllMenus();
      if (kDebugMode) {
        debugPrint('Reports fetched: ${reportsResult['data']?.length ?? 0}');
        debugPrint('Menus fetched: ${menusData['data']?.length ?? 0}');
      }
      if (!reportsResult['success'] || !menusData['success']) {
        throw Exception(reportsResult['message'] ?? menusData['message'] ?? 'Failed to load data');
      }
      setState(() {
        reports = List<Map<String, dynamic>>.from(reportsResult['data'] ?? []);
        menus = List<Map<String, dynamic>>.from(menusData['data'] ?? []);
        _applyFilter();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading data: $e');
      setState(() => errorMessage = 'Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      filteredReports = [];
      if (filterType == 'All') {
        filteredReports = List.from(reports);
      } else if (filterType == 'Daily' && selectedDate != null) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
        filteredReports = reports.where((report) {
          final reportDate = report['date'] != null ? DateTime.tryParse(report['date'].toString()) : null;
          return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == formattedDate;
        }).toList();
      } else if (filterType == 'Weekly' && selectedDate != null) {
        final startOfWeek = selectedDate!.subtract(Duration(days: selectedDate!.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        filteredReports = reports.where((report) {
          final reportDate = report['date'] != null ? DateTime.tryParse(report['date'].toString()) : null;
          return reportDate != null &&
              reportDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
              reportDate.isBefore(endOfWeek.add(const Duration(seconds: 1)));
        }).toList();
      } else if (filterType == 'Monthly' && selectedMonth != null) {
        final monthIndex = months.indexOf(selectedMonth!);
        if (monthIndex >= 0) {
          final formattedMonth = (monthIndex + 1).toString().padLeft(2, '0');
          final year = selectedYear.toString();
          filteredReports = reports.where((report) {
            final reportDate = report['date'] != null ? DateTime.tryParse(report['date'].toString()) : null;
            return reportDate != null &&
                DateFormat('MM').format(reportDate) == formattedMonth &&
                DateFormat('yyyy').format(reportDate) == year;
          }).toList();
        } else {
          setState(() => errorMessage = 'Invalid month selected');
        }
      } else {
        setState(() => errorMessage = 'Please select a valid ${filterType.toLowerCase()} filter');
      }
      if (kDebugMode) debugPrint('Filtered reports: ${filteredReports.length}');
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        errorMessage = null;
        if (filterType == 'Daily' || filterType == 'Weekly') _applyFilter();
      });
    }
  }

  Future<void> _downloadExcel() async {
    if (filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No reports to download')));
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['MDM Report'];
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Class Name'),
        TextCellValue('Total Students'),
        TextCellValue('Menu'),
        TextCellValue('Items Used'),
        TextCellValue('Class Group'),
      ]);

      for (final report in filteredReports) {
        final itemsUsed = (report['itemsUsed'] as List<dynamic>?)
            ?.map((item) => '${item['itemName'] ?? 'Unknown'}: ${item['requiredQuantity']?.toStringAsFixed(2) ?? '0'}')
            .join(', ') ?? 'None';
        final formattedDate = report['date'] != null && DateTime.tryParse(report['date'].toString()) != null
            ? DateFormat('dd-MM-yyyy').format(DateTime.parse(report['date'].toString()))
            : 'N/A';
        sheet.appendRow([
          TextCellValue(formattedDate),
          TextCellValue(report['className']?.toString() ?? 'N/A'),
          TextCellValue(report['totalStudents']?.toString() ?? '0'),
          TextCellValue(report['Menu']?['dishName']?.toString() ?? 'N/A'),
          TextCellValue(itemsUsed),
          TextCellValue(report['classGroup']?.toString() ?? 'N/A'),
        ]);
      }

      final excelBytes = excel.encode();
      if (excelBytes != null) {
        final fileName = 'MDM_Reports_${filterType}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(excelBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel downloaded: $fileName')));
      } else {
        throw Exception('Failed to generate Excel file');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Excel download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading Excel: $e')));
    }
  }

  void _openInventoryCalculationDialog() {
    if (menus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No menus available. Please add menus first.')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => InventoryCalculationDialog(
        onSubmit: (report) {
          setState(() {
            reports.add(report);
            _applyFilter();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report created successfully')));
        },
        classGroups: const ['1-5', '6-8'],
        menus: menus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDM Reports'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadExcel,
            tooltip: 'Download Reports as Excel',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Filter Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: filterType,
                              decoration: const InputDecoration(labelText: 'Filter Type', border: OutlineInputBorder()),
                              items: ['All', 'Daily', 'Weekly', 'Monthly']
                                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  filterType = value!;
                                  selectedMonth = null;
                                  selectedDate = null;
                                  errorMessage = null;
                                  _applyFilter();
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            if (filterType == 'Daily' || filterType == 'Weekly')
                              ListTile(
                                title: Text(
                                  selectedDate == null
                                      ? 'Select Date'
                                      : DateFormat('dd-MM-yyyy').format(selectedDate!),
                                ),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: _selectDate,
                              ),
                            if (filterType == 'Monthly') ...[
                              DropdownButtonFormField<String>(
                                value: selectedMonth,
                                decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                                items: months
                                    .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedMonth = value;
                                    errorMessage = null;
                                    _applyFilter();
                                  });
                                },
                                validator: (value) => value == null ? 'Select a month' : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: selectedYear,
                                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                                items: List.generate(10, (index) => DateTime.now().year - 5 + index)
                                    .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedYear = value!;
                                    errorMessage = null;
                                    _applyFilter();
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filteredReports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No reports found. Create a new report to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _openInventoryCalculationDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Create Report'),
                            ),
                          ],
                        ),
                      )
                    else
                      Card(
                        elevation: 2,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Class')),
                              DataColumn(label: Text('Students')),
                              DataColumn(label: Text('Menu')),
                              DataColumn(label: Text('Items Used')),
                              DataColumn(label: Text('Class Group')),
                            ],
                            rows: filteredReports.map((report) {
                              final itemsUsed = (report['itemsUsed'] as List<dynamic>?)
                                  ?.map((item) => '${item['itemName'] ?? 'Unknown'}: ${item['requiredQuantity']?.toStringAsFixed(2) ?? '0'}')
                                  .join(', ') ?? 'None';
                              final formattedDate = report['date'] != null && DateTime.tryParse(report['date'].toString()) != null
                                  ? DateFormat('dd-MM-yyyy').format(DateTime.parse(report['date'].toString()))
                                  : 'N/A';
                              return DataRow(cells: [
                                DataCell(Text(formattedDate)),
                                DataCell(Text(report['className']?.toString() ?? 'N/A')),
                                DataCell(Text(report['totalStudents']?.toString() ?? '0')),
                                DataCell(Text(report['Menu']?['dishName']?.toString() ?? 'N/A')),
                                DataCell(
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 150),
                                    child: Text(
                                      itemsUsed,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(Text(report['classGroup']?.toString() ?? 'N/A')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openInventoryCalculationDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}