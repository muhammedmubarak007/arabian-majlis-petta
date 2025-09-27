// deliveries_tab.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// For web download
import 'dart:html' as html;

class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key});

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab>
    with AutomaticKeepAliveClientMixin {
  String searchQuery = "";
  String searchBy = "name"; // "name", "location", or "billNo"
  String sortBy = "billNo"; // "billNo", "date", or "time"

  bool isDownloading = false;

  // ScrollControllers for smooth scrolling
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  String formatDateOnly(DateTime? dt) {
    if (dt == null) return "N/A";
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  String formatTimeAmPm(DateTime? dt) {
    if (dt == null) return "N/A";
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $amPm";
  }

  Future<void> downloadExcel(List<QueryDocumentSnapshot> deliveries) async {
    var excel = ex.Excel.createExcel();

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    ex.Sheet sheet = excel['Deliveries'];

    ex.CellStyle headerStyle = ex.CellStyle(
      bold: true,
      backgroundColorHex: ex.ExcelColor.cyan50,
      fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
    );

    List<String> headers = [
      "Bill No",
      "Delivery Boy",
      "Location",
      "Date",
      "Start Time",
      "End Time",
      "Total Time (mins)",
    ];

    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = ex.TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    for (int row = 0; row < deliveries.length; row++) {
      final data = deliveries[row].data() as Map<String, dynamic>;
      final startTime =
          (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final endTime =
          (data['stopAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final duration =
          data['durationMinutes'] ?? endTime.difference(startTime).inMinutes;

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1),
          )
          .value = ex.IntCellValue(
        int.tryParse(data['billNo']?.toString() ?? '0') ?? 0,
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1),
          )
          .value = ex.TextCellValue(
        data['createdBy'] ?? "Unknown",
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1),
          )
          .value = ex.TextCellValue(
        data['location'] ?? "N/A",
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row + 1),
          )
          .value = ex.TextCellValue(
        formatDateOnly(startTime),
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row + 1),
          )
          .value = ex.TextCellValue(
        formatTimeAmPm(startTime),
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row + 1),
          )
          .value = ex.TextCellValue(
        formatTimeAmPm(endTime),
      );

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row + 1),
          )
          .value = ex.IntCellValue(
        duration as int,
      );
    }

    final bytes = excel.save();

    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([Uint8List.fromList(bytes)]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final _ = html.AnchorElement(href: url)
          ..setAttribute("download", "deliveries.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/deliveries.xlsx";
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: "Deliveries Excel");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // important for keep-alive
    return Column(
      children: [
        // Search & Sort Row
        // Search & Sort Row
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Search Bar
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (searchBy == "name")
                              searchBy = "location";
                            else if (searchBy == "location")
                              searchBy = "billNo";
                            else
                              searchBy = "name";
                            searchQuery = "";
                          });
                        },
                        child: Icon(
                          searchBy == "name"
                              ? LucideIcons.user
                              : searchBy == "location"
                              ? LucideIcons.mapPin
                              : LucideIcons.fileText,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: searchBy == "name"
                                ? "Search by Name"
                                : searchBy == "location"
                                ? "Search by Location"
                                : "Search by Bill No",
                            hintStyle: const TextStyle(color: Colors.black54),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => setState(
                            () => searchQuery = val.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sortBy,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      LucideIcons.chevronDown,
                      color: Colors.black54,
                    ),
                    style: const TextStyle(color: Colors.black),
                    items: const [
                      DropdownMenuItem(
                        value: "billNo",
                        child: Row(
                          children: [
                            Icon(LucideIcons.fileText, size: 20),
                            SizedBox(width: 4),
                            Text("Bill No"),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: "date",
                        child: Row(
                          children: [
                            Icon(LucideIcons.calendar, size: 20),
                            SizedBox(width: 4),
                            Text("Date"),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: "time",
                        child: Row(
                          children: [
                            Icon(LucideIcons.clock, size: 20),
                            SizedBox(width: 4),
                            Text("Duration"),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => sortBy = val!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isDownloading
                    ? null
                    : () async {
                        setState(() => isDownloading = true);
                        final snapshot = await FirebaseFirestore.instance
                            .collection("deliveries")
                            .get();
                        await downloadExcel(snapshot.docs);
                        setState(() => isDownloading = false);
                      },
                icon: isDownloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(LucideIcons.download, color: Colors.black),
                tooltip: "Download Excel",
              ),
            ],
          ),
        ),

        // Deliveries Table
        // Deliveries Table
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("deliveries")
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var deliveries = snapshot.data!.docs;

              // Filter by search
              final query = searchQuery.trim().toLowerCase();
              deliveries = deliveries.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['createdBy'] ?? "").toString().toLowerCase();
                final location = (data['location'] ?? "")
                    .toString()
                    .toLowerCase();
                final billNo = (data['billNo']?.toString() ?? "").toLowerCase();
                if (query.isEmpty) return true;
                if (searchBy == "name") return name.contains(query);
                if (searchBy == "location") return location.contains(query);
                return billNo.contains(query);
              }).toList();

              // Sort
              deliveries.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;

                final billA =
                    int.tryParse(dataA['billNo']?.toString() ?? '0') ?? 0;
                final billB =
                    int.tryParse(dataB['billNo']?.toString() ?? '0') ?? 0;

                final startA =
                    (dataA['startAt'] as Timestamp?)?.toDate() ??
                    DateTime(2000);
                final startB =
                    (dataB['startAt'] as Timestamp?)?.toDate() ??
                    DateTime(2000);

                final durationA =
                    (dataA['durationMinutes'] ??
                            ((dataA['stopAt'] as Timestamp?)
                                    ?.toDate()
                                    .difference(startA)
                                    .inMinutes ??
                                0))
                        as int;
                final durationB =
                    (dataB['durationMinutes'] ??
                            ((dataB['stopAt'] as Timestamp?)
                                    ?.toDate()
                                    .difference(startB)
                                    .inMinutes ??
                                0))
                        as int;

                switch (sortBy) {
                  case 'billNo':
                    return billA.compareTo(billB);
                  case 'date':
                    return startA.compareTo(startB);
                  case 'time':
                    return durationA.compareTo(durationB);
                  default:
                    return 0;
                }
              });

              if (deliveries.isEmpty)
                return const Center(
                  child: Text(
                    "No deliveries found",
                    style: TextStyle(color: Colors.black54),
                  ),
                );

              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey[100],
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected))
                          return Colors.grey[200];
                        return Colors.white;
                      }),
                      columns: const [
                        DataColumn(
                          label: Text(
                            "Bill No",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "delivery",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Location",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Date",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Start",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "End",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Duration (min)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: deliveries.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final startTime = (data['startAt'] as Timestamp?)
                            ?.toDate();
                        final endTime = (data['stopAt'] as Timestamp?)
                            ?.toDate();
                        final duration =
                            data['durationMinutes'] ??
                            ((startTime != null && endTime != null)
                                ? endTime.difference(startTime).inMinutes
                                : 0);

                        return DataRow(
                          cells: [
                            DataCell(Text(data['billNo']?.toString() ?? "N/A")),
                            DataCell(Text(data['createdBy'] ?? "Unknown")),
                            DataCell(Text(data['location'] ?? "N/A")),
                            DataCell(Text(formatDateOnly(startTime))),
                            DataCell(Text(formatTimeAmPm(startTime))),
                            DataCell(Text(formatTimeAmPm(endTime))),
                            DataCell(Text(duration.toString())),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
