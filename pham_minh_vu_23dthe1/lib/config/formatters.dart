/// Định dạng giá: 150000 -> "150.000", 299000.5 -> "299.000,5"
String formatPrice(double price) {
  final isWhole = price == price.roundToDouble();
  final text = isWhole ? price.toInt().toString() : price.toString();
  final parts = text.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
}

/// Hiển thị thời gian kiểu mạng xã hội: "vừa xong", "5 phút trước", "2 giờ trước"...
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year} ${two(time.hour)}:${two(time.minute)}';
}
