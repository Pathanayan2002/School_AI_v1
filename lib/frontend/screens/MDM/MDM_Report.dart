import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/login.dart';
import '../services/api_client.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'inventory_calculation.dart';

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
    setState(() => isLoading = true);
    try {
      final reportsResult = await _apiService.getAllReports();
      final menusData = await _apiService.getAllMenus();
      setState(() {
        reports = List<Map<String, dynamic>>.from(reportsResult['data'] ?? []);
        menus = List<Map<String, dynamic>>.from(menusData['data'] ?? []);
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleError(dynamic result) {
    setState(() => isLoading = false);
    final statusCode = result['statusCode'] ?? 500;
    final statusMessage = result['statusMessage'] ?? 'Unknown error';
    if (statusCode == 401) {
      _apiService.deleteJwtToken(); // Assuming this method exists in ApiService
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(statusMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _applyFilter() {
    setState(() {
      if (filterType == 'All') {
        filteredReports = List.from(reports);
      } else if (filterType == 'Daily' && selectedDate != null) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
        filteredReports = reports.where((report) {
          final reportDate = report['date'] != null ? DateTime.parse(report['date']) : null;
          return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == formattedDate;
        }).toList();
      } else if (filterType == 'Weekly' && selectedDate != null) {
        final startOfWeek = selectedDate!.subtract(Duration(days: selectedDate!.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        filteredReports = reports.where((report) {
          final reportDate = report['date'] != null ? DateTime.parse(report['date']) : null;
          return reportDate != null &&
              reportDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              reportDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();
      } else if (filterType == 'Monthly' && selectedMonth != null) {
        final monthIndex = months.indexOf(selectedMonth!);
        if (monthIndex != -1) {
          final formattedMonth = (monthIndex + 1).toString().padLeft(2, '0');
          final year = selectedYear.toString();
          filteredReports = reports.where((report) {
            final reportDate = report['date'] != null ? DateTime.parse(report['date']) : null;
            return reportDate != null &&
                DateFormat('MM').format(reportDate) == formattedMonth &&
                DateFormat('yyyy').format(reportDate) == year;
          }).toList();
        } else {
          filteredReports = [];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid month selected'), backgroundColor: Colors.red),
          );
        }
      } else {
        filteredReports = [];
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        if (filterType == 'Daily' || filterType == 'Weekly') {
          _applyFilter();
        }
      });
    }
  }

  Future<void> _downloadExcel() async {
    if (filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reports to download'), backgroundColor: Colors.red),
      );
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['MDM Report'];

    final generationDate = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('MDM Report\nGenerated on: $generationDate IST');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Class Name'),
      TextCellValue('Total Students'),
      TextCellValue('Menu'),
      TextCellValue('Items Used'),
      TextCellValue('Class Group'),
    ]);
    for (var cell in sheet.row(1)) {
      if (cell != null) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FF2196F3'),
          fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
    }

    for (var report in filteredReports) {
      final itemsUsed = (report['itemsUsed'] as List?)
              ?.map((item) => '${item['itemName']}: ${item['requiredQuantity']}')
              .join(', ') ??
          '';
      final formattedDate = report['date'] != null
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(report['date']))
          : '';
      sheet.appendRow([
        TextCellValue(formattedDate),
        TextCellValue(report['className']?.toString() ?? ''),
        TextCellValue(report['totalStudents']?.toString() ?? '0'),
        TextCellValue(report['Menu']?['dishName']?.toString() ?? ''),
        TextCellValue(itemsUsed),
        TextCellValue(report['classGroup']?.toString() ?? ''),
      ]);
    }

    final excelBytes = excel.encode();
    if (excelBytes != null) {
      final fileName = 'MDM_Reports_${filterType}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(excelBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel downloaded: $fileName'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _openInventoryCalculationDialog() async {
    await showDialog(
      context: context,
      builder: (_) => InventoryCalculationDialog(
        onSubmit: (reportData) {
          setState(() {
            reports.add(reportData);
            _applyFilter();
          });
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
        title: const Text('MDM Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Reports',
            onPressed: _downloadExcel,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New Report',
            onPressed: _openInventoryCalculationDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: filterType,
                        decoration: const InputDecoration(
                          labelText: 'Filter Reports',
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', 'Daily', 'Weekly', 'Monthly']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            filterType = value!;
                            if (filterType != 'Monthly') {
                              selectedMonth = null;
                            }
                            if (filterType != 'Daily' && filterType != 'Weekly') {
                              selectedDate = null;
                            }
                            _applyFilter();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (filterType == 'Daily' || filterType == 'Weekly')
                        ListTile(
                          title: Text(
                            selectedDate == null
                                ? 'Select Date'
                                : 'Date: ${DateFormat('dd-MM-yyyy').format(selectedDate!)}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context),
                        ),
                      if (filterType == 'Monthly') ...[
                        DropdownButtonFormField<String>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Select Month',
                            border: OutlineInputBorder(),
                          ),
                          items: months
                              .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value;
                              _applyFilter();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Select Year',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(10, (index) => DateTime.now().year - 5 + index)
                              .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value!;
                              _applyFilter();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeIn(
                  duration: const Duration(milliseconds: 400),
                  child: const Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredReports.isEmpty
                      ? const Center(
                          child: Text(
                            'No reports found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  dataRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                  headingRowColor: WidgetStateProperty.all(
                                    Theme.of(context).primaryColor.withOpacity(0.1),
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Date',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Class Name',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Total Students',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Menu',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Items Used',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Class Group',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  rows: filteredReports.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final report = entry.value;
                                    final itemsUsed = (report['itemsUsed'] as List?)
                                            ?.map((item) => '${item['itemName']}: ${item['requiredQuantity']}')
                                            .join(', ') ??
                                        '';
                                    final formattedDate = report['date'] != null
                                        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(report['date']))
                                        : '';
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(formattedDate)),
                                        DataCell(Text(report['className']?.toString() ?? '')),
                                        DataCell(Text(report['totalStudents']?.toString() ?? '0')),
                                        DataCell(Text(report['Menu']?['dishName']?.toString() ?? '')),
                                        DataCell(
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 200),
                                            child: Text(
                                              itemsUsed,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(report['classGroup']?.toString() ?? '')),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openInventoryCalculationDialog,
        backgroundColor: Theme.of(context).primaryColor,
        tooltip: 'Create New Report',
        child: const Icon(Icons.add),
      ),
    );
  }
}