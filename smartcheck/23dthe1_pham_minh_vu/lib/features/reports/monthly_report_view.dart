import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/models/attendance_report.dart';
import '../shared/common.dart';
import 'report_format.dart';

/// Bảng công theo tháng: đổi tháng bằng hai mũi tên, ba ô tổng (ngày công, đi trễ, về sớm) và
/// (cho Admin/Manager) danh sách từng nhân viên.
class MonthlyReportView extends StatefulWidget {
  const MonthlyReportView({super.key, required this.load, required this.showPeople});

  final Future<MonthlyReport> Function(int year, int month) load;

  /// `true`: liệt kê từng nhân viên (Admin/Manager). `false`: chỉ các ô tổng của chính mình.
  final bool showPeople;

  @override
  State<MonthlyReportView> createState() => _MonthlyReportViewState();
}

class _MonthlyReportViewState extends State<MonthlyReportView> {
  late DateTime _month = DateTime(nowProvider().year, nowProvider().month);
  MonthlyReport? _report;
  String? _error;
  bool _loading = true;

  bool get _isCurrentMonth {
    final n = nowProvider();
    return _month.year == n.year && _month.month == n.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load(month.year, month.month);
      if (mounted && month == _month) setState(() => _report = r);
    } on ApiException catch (e) {
      if (mounted && month == _month) setState(() => _error = e.message);
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _report = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(key: const Key('month-prev'), tooltip: 'Tháng trước', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(monthTitle(_month.year, _month.month),
                    key: const Key('month-title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              IconButton(key: const Key('month-next'), tooltip: 'Tháng sau', onPressed: _isCurrentMonth ? null : () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading && _report == null) return const LoadingView();
    if (_error != null && _report == null) return ErrorView(message: _error!, onRetry: _load);
    final r = _report!;
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            _Stat(label: 'Ngày công', value: r.totalDays, color: AppColors.ink),
            const SizedBox(width: 10),
            _Stat(label: 'Đi trễ', value: r.totalLate, color: r.totalLate > 0 ? AppColors.amberDark : AppColors.ok),
            const SizedBox(width: 10),
            _Stat(label: 'Về sớm', value: r.totalEarly, color: r.totalEarly > 0 ? AppColors.amberDark : AppColors.ok),
          ]),
          const SizedBox(height: 16),
          if (r.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyView(icon: Icons.event_busy_outlined, title: 'Chưa có chấm công trong tháng này'),
            )
          else if (widget.showPeople) ...[
            Text('Theo nhân viên (${r.rows.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            for (final row in r.rows) ...[_PersonCard(row), const SizedBox(height: 10)],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.paperDeep)),
          child: Column(children: [
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
      );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard(this.row);
  final ReportRow row;

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => ItemCard(
        leading: CircleAvatar(radius: 22, backgroundColor: AppColors.ink, child: Text(_initials(row.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        title: row.name.isEmpty ? 'Không rõ' : row.name,
        subtitle: Text('${row.daysWorked} ngày công', style: const TextStyle(color: AppColors.textMuted)),
        footer: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            StatusChip('Đi trễ ${row.lateCount}', row.lateCount > 0 ? AppColors.amberDark : AppColors.ok),
            StatusChip('Về sớm ${row.earlyLeaveCount}', row.earlyLeaveCount > 0 ? AppColors.amberDark : AppColors.ok),
          ]),
        ),
      );
}
