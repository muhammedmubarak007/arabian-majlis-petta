import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Model for an active delivery item
class ActiveDeliveryItem {
  final String bill;
  final String location;
  final DateTime? startTime;
  final String assignedTo;
  final String assignedToEmail;
  final String assignedToName;
  final String? documentId;
  final int elapsedSeconds;

  ActiveDeliveryItem({
    required this.bill,
    required this.location,
    this.startTime,
    required this.assignedTo,
    required this.assignedToEmail,
    required this.assignedToName,
    this.documentId,
    this.elapsedSeconds = 0,
  });

  ActiveDeliveryItem copyWith({
    String? bill,
    String? location,
    DateTime? startTime,
    String? assignedTo,
    String? assignedToEmail,
    String? assignedToName,
    String? documentId,
    int? elapsedSeconds,
  }) {
    return ActiveDeliveryItem(
      bill: bill ?? this.bill,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedToName: assignedToName ?? this.assignedToName,
      documentId: documentId ?? this.documentId,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

class ActiveDeliveriesTab extends StatefulWidget {
  const ActiveDeliveriesTab({super.key});

  @override
  State<ActiveDeliveriesTab> createState() => _ActiveDeliveriesTabState();
}

class _ActiveDeliveriesTabState extends State<ActiveDeliveriesTab> {
  List<ActiveDeliveryItem> activeDeliveries = [];
  Timer? timer;
  bool isLoading = false;
  String? completingDeliveryId;

  @override
  void initState() {
    super.initState();
    _loadActiveDeliveries();
    _startTimer();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTimeAmPm(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $amPm";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        activeDeliveries = activeDeliveries.map((delivery) {
          if (delivery.startTime != null) {
            final now = DateTime.now();
            final elapsed = now.difference(delivery.startTime!).inSeconds;
            return delivery.copyWith(elapsedSeconds: elapsed);
          }
          return delivery;
        }).toList();
      });
    });
  }

  Future<void> _loadActiveDeliveries() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get today's orders and filter client-side to avoid index issues
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (!mounted) return;

      setState(() {
        // Filter for active orders only and map to ActiveDeliveryItem
        final activeOrders = snapshot.docs.where((doc) {
          final data = doc.data();
          final status = data['status'];
          return status == 'active';
        }).toList();

        activeDeliveries = activeOrders.map((doc) {
          final data = doc.data();
          final startTime = data['startAt'] != null
              ? (data['startAt'] as Timestamp).toDate()
              : null;

          int elapsedSeconds = 0;
          if (startTime != null) {
            elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
          }

          return ActiveDeliveryItem(
            bill: data['billNo'] ?? '',
            location: data['location'] ?? '',
            startTime: startTime,
            assignedTo: data['assignedTo'] ?? '',
            assignedToEmail: data['assignedToEmail'] ?? '',
            assignedToName: data['assignedToName'] ?? '',
            documentId: doc.id,
            elapsedSeconds: elapsedSeconds,
          );
        }).toList();

        // Sort by startAt descending (newest first)
        activeDeliveries.sort((a, b) {
          if (a.startTime == null && b.startTime == null) return 0;
          if (a.startTime == null) return 1;
          if (b.startTime == null) return -1;
          return b.startTime!.compareTo(a.startTime!);
        });
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error loading active deliveries: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _completeDelivery(ActiveDeliveryItem delivery) async {
    if (completingDeliveryId != null) return; // Prevent multiple clicks

    setState(() => completingDeliveryId = delivery.documentId);

    try {
      if (delivery.documentId == null) {
        print('Error: Document ID is null for delivery ${delivery.bill}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Document ID is null')),
        );
        return;
      }

      print('Starting to complete delivery: ${delivery.bill}');
      print('Document ID: ${delivery.documentId}');
      print('Assigned to: ${delivery.assignedTo}');
      print('Assigned to email: ${delivery.assignedToEmail}');

      final stopTime = DateTime.now();
      final durationMinutes = delivery.startTime != null
          ? stopTime.difference(delivery.startTime!).inMinutes
          : 0;

      // Update order status to completed
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(delivery.documentId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': delivery.assignedToEmail,
            'durationMinutes': durationMinutes,
          });

      // Add to deliveries collection for historical tracking
      print('Creating delivery record with userId: ${delivery.assignedTo}');
      await FirebaseFirestore.instance.collection("deliveries").add({
        "billNo": delivery.bill,
        "location": delivery.location,
        "startAt": delivery.startTime != null
            ? Timestamp.fromDate(delivery.startTime!)
            : null,
        "stopAt": Timestamp.fromDate(stopTime),
        "durationMinutes": durationMinutes,
        "createdBy": delivery.assignedToEmail,
        "assignedTo": delivery.assignedTo,
        "assignedToName": delivery.assignedToName,
        "userId": delivery.assignedTo, // Required by security rules
        "createdAt": FieldValue.serverTimestamp(),
      });
      print('Delivery record created successfully');

      // Reload active deliveries to refresh the list
      await _loadActiveDeliveries();

      if (!mounted) return;
      _showSuccessSnackBar('Delivery completed successfully!');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error completing delivery: $e');
    } finally {
      if (mounted) {
        setState(() => completingDeliveryId = null);
      }
    }
  }

  String formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) {
      return "${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
    }
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.black12, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Active Deliveries",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.moped, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        "${activeDeliveries.length}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : activeDeliveries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delivery_dining,
                          size: 64,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No active deliveries",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Start deliveries to see them here",
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeDeliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = activeDeliveries[index];
                      return Card(
                        color: Colors.white,
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: const Icon(
                                      Icons.delivery_dining,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Bill No : ${delivery.bill}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      "ACTIVE",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Location
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      delivery.location,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Time information
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    31,
                                    113,
                                    113,
                                    113,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Elapsed Time",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          formatTime(delivery.elapsedSeconds),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (delivery.startTime != null)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            "Started At",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            _formatTimeAmPm(
                                              delivery.startTime!,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Complete button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: completingDeliveryId != null
                                      ? null
                                      : () => _completeDelivery(delivery),
                                  icon:
                                      completingDeliveryId ==
                                          delivery.documentId
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.check,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    completingDeliveryId == delivery.documentId
                                        ? "Completing..."
                                        : "Complete",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
