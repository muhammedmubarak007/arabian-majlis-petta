import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'role_selection.dart';
import 'change_password_page.dart';
import 'active_deliveries_tab.dart';
import 'pending_orders_tab.dart';

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

/// Main delivery dashboard page
class DeliveryDashboard extends StatefulWidget {
  final User user;
  const DeliveryDashboard({super.key, required this.user});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'change_password':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        );
        break;
      case 'logout':
        _showLogoutConfirmation();
        break;
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear saved login state
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Delivery Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Available Orders"),
            Tab(text: "My Deliveries"),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'change_password',
                child: ListTile(
                  leading: Icon(LucideIcons.key, color: Colors.black),
                  title: Text(
                    'Change Password',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(LucideIcons.logOut, color: Colors.black),
                  title: Text('Logout', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
            icon: const Icon(LucideIcons.moreVertical, color: Colors.black),
            color: Colors.white,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PendingOrdersTab(user: widget.user),
          ActiveDeliveriesTab(),
        ],
      ),
    );
  }
}

/// Active deliveries page
class ActiveDeliveriesPage extends StatefulWidget {
  final User user;
  final List<DeliveryItem> initialDeliveries;

  const ActiveDeliveriesPage({
    super.key,
    required this.user,
    required this.initialDeliveries,
  });

  @override
  State<ActiveDeliveriesPage> createState() => _ActiveDeliveriesPageState();
}

class _ActiveDeliveriesPageState extends State<ActiveDeliveriesPage> {
  late List<DeliveryItem> deliveries;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    deliveries = widget.initialDeliveries;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        deliveries = deliveries
            .map(
              (d) => d.running
                  ? d.copyWith(elapsedSeconds: d.elapsedSeconds + 1)
                  : d,
            )
            .toList();
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
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

  Future<void> _reachDelivery(DeliveryItem delivery) async {
    if (delivery.startTime == null) return;

    final stopTime = DateTime.now();
    final durationMinutes = stopTime.difference(delivery.startTime!).inMinutes;

    setState(() {
      deliveries.remove(delivery);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Delivery completed!"),
        duration: Duration(seconds: 2),
      ),
    );

    // Update order status to completed
    if (delivery.documentId != null) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(delivery.documentId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': widget.user.email ?? 'Unknown',
          });
    }

    // Also add to deliveries collection for historical tracking
    FirebaseFirestore.instance.collection("deliveries").add({
      "billNo": delivery.bill,
      "location": delivery.location,
      "startAt": Timestamp.fromDate(delivery.startTime!),
      "stopAt": Timestamp.fromDate(stopTime),
      "durationMinutes": durationMinutes,
      "createdBy": widget.user.email ?? "Unknown",
      "userId": widget.user.uid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (deliveries.isEmpty) {
      timer?.cancel();
      if (mounted) {
        Navigator.pop(context, deliveries);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "My Deliveries",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: deliveries.isEmpty
          ? const Center(
              child: Text(
                "No active deliveries",
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final d = deliveries[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.delivery_dining, color: Colors.black),
                    ),
                    title: Text(
                      "Bill No : ${d.bill}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "Time: ${formatTime(d.elapsedSeconds)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _reachDelivery(d),
                      icon: const Icon(LucideIcons.check, color: Colors.white),
                      label: const Text(
                        "Complete",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
