// ----- Helper functions -----
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
