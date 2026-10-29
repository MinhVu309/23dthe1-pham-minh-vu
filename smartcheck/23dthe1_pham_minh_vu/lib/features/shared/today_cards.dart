import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/models/attendance_report.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/fraud_repository.dart';
import '../reports/report_format.dart';
import 'status_card.dart';

/// Nhân viên: trạng thái chấm công vào/ra của hôm nay (thẻ trên đầu trang chủ).
class EmployeeTodayCard extends StatefulWidget {
  const EmployeeTodayCard({super.key, required this.refreshToken});

  final int refreshToken;

  @override
  State<EmployeeTodayCard> createState() => _EmployeeTodayCardState();
}

class _EmployeeTodayCardState extends State<EmployeeTodayCard> {
  DayLog? _today;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeTodayCard old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final repo = context.read<AttendanceRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = nowProvider();
      final day = DateTime(now.year, now.month, now.day);
      final logs = groupByDay(await repo.mine(days: 2));
      if (mounted) setState(() => _today = logs.where((l) => l.day == day).firstOrNull);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  StatusRow _row(Color dot, String label, MyAttendance? a, String bad) {
    if (a == null) return StatusRow(color: dot, label: label, value: 'Chưa chấm công', valueColor: AppColors.textMuted);
    final isBad = bad == 'Đi trễ' ? a.isLate : a.isEarlyLeave;
    return StatusRow(color: dot, label: label, value: '${formatTime(a.time)} · ${isBad ? bad : 'Đúng giờ'}', valueColor: isBad ? AppColors.amberDark : AppColors.ink);
  }

  @override
  Widget build(BuildContext context) => StatusCard(
        loading: _loading,
        error: _error,
        onRefresh: _load,
        rows: [
          _row(AppColors.sky, 'Vào ca hôm nay', _today?.checkIn, 'Đi trễ'),
          _row(AppColors.amber, 'Ra ca hôm nay', _today?.checkOut, 'Về sớm'),
        ],
      );
}

/// Admin/Manager: số lượt chấm công hôm nay và số cảnh báo gian lận chưa xử lý.
class StaffTodayCard extends StatefulWidget {
  const StaffTodayCard({super.key, required this.refreshToken});

  final int refreshToken;

  @override
  State<StaffTodayCard> createState() => _StaffTodayCardState();
}

class _StaffTodayCardState extends State<StaffTodayCard> {
  int? _total;
  int? _open;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StaffTodayCard old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final attendance = context.read<AttendanceRepository>();
    final fraud = context.read<FraudRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = nowProvider();
      final totalFuture = attendance.list(from: DateTime(now.year, now.month, now.day), pageSize: 1);
      final openFuture = fraud.list(resolved: false);
      await Future.wait([totalFuture, openFuture]); // ném lại lỗi gốc nếu có lời gọi hỏng
      final total = (await totalFuture).total;
      final open = (await openFuture).length;
      if (mounted) {
        setState(() {
          _total = total;
          _open = open;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => StatusCard(
        loading: _loading,
        error: _error,
        onRefresh: _load,
        rows: [
          StatusRow(color: AppColors.sky, label: 'Chấm công hôm nay', value: _total == null ? '--' : '$_total lượt'),
          StatusRow(
            color: AppColors.amber,
            label: 'Cảnh báo gian lận chưa xử lý',
            value: _open == null ? '--' : '$_open',
            valueColor: (_open ?? 0) > 0 ? AppColors.danger : AppColors.ok,
          ),
        ],
      );
}
