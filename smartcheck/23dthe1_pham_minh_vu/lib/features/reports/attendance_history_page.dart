import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models/attendance_report.dart';
import '../../data/repositories/attendance_repository.dart';
import '../shared/common.dart';
import 'monthly_report_view.dart';
import 'report_format.dart';

/// Nhân viên: lịch sử chấm công của mình và bảng công theo tháng.
class AttendanceHistoryPage extends StatelessWidget {
  const AttendanceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AttendanceRepository>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lịch sử chấm công', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [Tab(text: 'Lịch sử'), Tab(text: 'Bảng công tháng')]),
        ),
        body: TabBarView(children: [
          const _HistoryTab(),
          MonthlyReportView(showPeople: false, load: (y, m) => repo.report(year: y, month: m)),
        ]),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> with AutomaticKeepAliveClientMixin {
  static const _ranges = [7, 30, 90];

  int _days = 30;
  List<DayLog>? _logs;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AttendanceRepository>();
    final days = _days;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await repo.mine(days: days);
      if (mounted && days == _days) setState(() => _logs = groupByDay(items));
    } on ApiException catch (e) {
      if (mounted && days == _days) setState(() => _error = e.message);
    } finally {
      if (mounted && days == _days) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget body;
    if (_loading && _logs == null) {
      body = const LoadingView();
    } else if (_error != null && _logs == null) {
      body = ErrorView(message: _error!, onRetry: _load);
    } else if (_logs!.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 80),
        EmptyView(icon: Icons.history_toggle_off_rounded, title: 'Chưa có lượt chấm công', subtitle: 'Trong $_days ngày gần nhất bạn chưa chấm công lần nào.'),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _logs!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DayCard(_logs![i]),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        FilterChips<int>(options: _ranges, selected: _days, labelOf: (d) => '$d ngày', onChanged: (d) {
          if (d == _days) return;
          setState(() {
            _days = d;
            _logs = null;
          });
          _load();
        }),
        const SizedBox(height: 8),
        Expanded(child: RefreshIndicator(color: AppColors.ink, onRefresh: _load, child: body)),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard(this.log);
  final DayLog log;

  @override
  Widget build(BuildContext context) {
    final place = (log.checkIn ?? log.checkOut)?.location ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.paperDeep)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatDayWithWeekday(log.day), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
          if (place.isNotEmpty) Text(place, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 10),
          _line(Icons.login_rounded, 'Vào ca', log.checkIn, onTimeLabel: 'Đúng giờ', badLabel: 'Đi trễ', isBad: log.checkIn?.isLate ?? false),
          const SizedBox(height: 6),
          _line(Icons.logout_rounded, 'Ra ca', log.checkOut, onTimeLabel: 'Đúng giờ', badLabel: 'Về sớm', isBad: log.checkOut?.isEarlyLeave ?? false),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, MyAttendance? a, {required String onTimeLabel, required String badLabel, required bool isBad}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkSoft),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        const Spacer(),
        if (a == null)
          const Text('Chưa chấm công', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
        else ...[
          Text(formatTime(a.time), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(width: 10),
          StatusChip(isBad ? badLabel : onTimeLabel, isBad ? AppColors.amberDark : AppColors.ok),
        ],
      ],
    );
  }
}
