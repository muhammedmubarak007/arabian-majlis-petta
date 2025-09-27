import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Model for a delivery item
class DeliveryItem {
  final String bill;
  final String location;
  final DateTime? startTime;
  final bool running;
  final int elapsedSeconds;
  final String status;
  final String? assignedTo;
  final String? assignedToEmail;
  final String? assignedToName;
  final String? documentId;

  DeliveryItem({
    required this.bill,
    required this.location,
    this.startTime,
    this.running = false,
    this.elapsedSeconds = 0,
    this.status = 'pending',
    this.assignedTo,
    this.assignedToEmail,
    this.assignedToName,
    this.documentId,
  });

  DeliveryItem copyWith({
    String? bill,
    String? location,
    DateTime? startTime,
    bool? running,
    int? elapsedSeconds,
    String? status,
    String? assignedTo,
    String? assignedToEmail,
    String? assignedToName,
    String? documentId,
  }) {
    return DeliveryItem(
      bill: bill ?? this.bill,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      running: running ?? this.running,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedToName: assignedToName ?? this.assignedToName,
      documentId: documentId ?? this.documentId,
    );
  }
}

class PendingOrdersTab extends StatefulWidget {
  final User user;
  const PendingOrdersTab({super.key, required this.user});

  @override
  State<PendingOrdersTab> createState() => _PendingOrdersTabState();
}

class _PendingOrdersTabState extends State<PendingOrdersTab> {
  List<DeliveryItem> deliveries = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
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

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Load pending orders and selected orders by current user for today only
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      final selectedSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'selected')
          .where('assignedToEmail', isEqualTo: widget.user.email)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      List<DeliveryItem> allOrders = [];

      // Add pending orders
      allOrders.addAll(
        pendingSnapshot.docs.map((doc) {
          final data = doc.data();
          return DeliveryItem(
            bill: data['billNo'] ?? '',
            location: data['location'] ?? '',
            status: data['status'] ?? 'pending',
            assignedTo: data['assignedTo'],
            assignedToEmail: data['assignedToEmail'],
            assignedToName: data['assignedToName'],
            documentId: doc.id,
          );
        }),
      );

      // Add selected orders by current user
      allOrders.addAll(
        selectedSnapshot.docs.map((doc) {
          final data = doc.data();
          return DeliveryItem(
            bill: data['billNo'] ?? '',
            location: data['location'] ?? '',
            status: data['status'] ?? 'selected',
            assignedTo: data['assignedTo'],
            assignedToEmail: data['assignedToEmail'],
            assignedToName: data['assignedToName'],
            documentId: doc.id,
          );
        }),
      );

      if (!mounted) return;

      setState(() {
        deliveries = allOrders;

        // Sort orders by status: selected first, then pending
        deliveries.sort((a, b) {
          const statusOrder = {
            'selected': 0,
            'pending': 1,
            'active': 2,
            'completed': 3,
          };
          final aOrder = statusOrder[a.status] ?? 4;
          final bOrder = statusOrder[b.status] ?? 4;
          return aOrder.compareTo(bOrder);
        });
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectOrder(DeliveryItem delivery) async {
    if (!mounted) return;

    try {
      if (delivery.documentId == null) {
        _showErrorSnackBar('Error: Document ID is null');
        return;
      }

      // Get a better display name for the user
      String displayName =
          widget.user.displayName ??
          (widget.user.email != null
              ? widget.user.email!
                    .split('@')
                    .first
                    .replaceAll('.', ' ')
                    .split(' ')
                    .map(
                      (word) => word.isNotEmpty
                          ? word[0].toUpperCase() + word.substring(1)
                          : '',
                    )
                    .join(' ')
              : 'User');

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(delivery.documentId)
          .update({
            'status': 'selected',
            'assignedTo': widget.user.uid,
            'assignedToEmail': widget.user.email ?? 'Unknown',
            'assignedToName': displayName,
            'selectedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      _showSuccessSnackBar('Order selected successfully!');
      _loadOrders();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error selecting order: $e');
    }
  }

  Future<void> _unselectOrder(DeliveryItem delivery) async {
    if (!mounted) return;

    try {
      if (delivery.documentId == null) {
        _showErrorSnackBar('Error: Document ID is null');
        return;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(delivery.documentId)
          .update({
            'status': 'pending',
            'assignedTo': null,
            'assignedToEmail': null,
            'assignedToName': null,
            'selectedAt': null,
          });

      if (!mounted) return;

      _showSuccessSnackBar('Order removed from selection!');
      _loadOrders();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error unselecting order: $e');
    }
  }

  Future<void> _startDelivery(DeliveryItem delivery) async {
    if (!mounted) return;

    try {
      if (delivery.documentId == null) {
        _showErrorSnackBar('Error: Document ID is null');
        return;
      }

      // Update order status to active
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(delivery.documentId)
          .update({
            'status': 'active',
            'startAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      _showSuccessSnackBar('Delivery started successfully!');
      _loadOrders();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error starting delivery: $e');
    }
  }

  Future<void> _startAll() async {
    if (!mounted) return;

    final selectedDeliveries = deliveries
        .where((d) => d.status == 'selected')
        .toList();

    if (selectedDeliveries.isEmpty) {
      _showErrorSnackBar('No selected orders to start!');
      return;
    }

    try {
      // Start all selected deliveries
      int successCount = 0;
      for (var delivery in selectedDeliveries) {
        if (delivery.documentId != null) {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(delivery.documentId)
              .update({
                'status': 'active',
                'startAt': FieldValue.serverTimestamp(),
              });
          successCount++;
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        _showSuccessSnackBar('$successCount deliveries started successfully!');
        _loadOrders();
      } else {
        _showErrorSnackBar('No deliveries could be started');
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error starting deliveries: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User Info Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.black12,
                    radius: 28,
                    child: Icon(
                      LucideIcons.user,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.email ?? "User",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Delivery boy",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          if (deliveries.any((d) => d.status == 'selected'))
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startAll,
                        icon: const Icon(
                          LucideIcons.play,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "Start All",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Start all selected orders",
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          if (deliveries.any((d) => d.status == 'selected'))
            const SizedBox(height: 20),

          // Pending Orders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Pending Orders",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.package, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "${deliveries.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (deliveries.isEmpty)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: const Text(
                "No orders available",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final d = deliveries[index];
                return Card(
                  color: Colors.white,
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with bill number and status
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.black12,
                              radius: 20,
                              child: Icon(
                                Icons.moped,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bill No : ${d.bill}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.mapPin,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          d.location,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: d.status == 'pending'
                                    ? Colors.amber
                                    : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                d.status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action buttons - responsive layout
                        if (d.status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                LucideIcons.userPlus,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                "Select",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _selectOrder(d),
                            ),
                          )
                        else if (d.status == 'selected')
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    LucideIcons.play,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "Start",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _startDelivery(d),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "Remove",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _unselectOrder(d),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
