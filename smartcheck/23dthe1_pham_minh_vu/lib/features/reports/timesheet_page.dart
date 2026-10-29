import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/models/attendance.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/employee.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../shared/common.dart';
import 'monthly_report_view.dart';
import 'report_format.dart';

/// Admin/Manager: chấm công của nhân viên theo ngày và bảng công theo tháng.
class TimesheetPage extends StatelessWidget {
  const TimesheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AttendanceRepository>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bảng công', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [Tab(text: 'Theo ngày'), Tab(text: 'Theo tháng')]),
        ),
        body: TabBarView(children: [
          const _DayListTab(),
          MonthlyReportView(showPeople: true, load: (y, m) => repo.report(year: y, month: m)),
        ]),
      ),
    );
  }
}

class _DayListTab extends StatefulWidget {
  const _DayListTab();

  @override
  State<_DayListTab> createState() => _DayListTabState();
}

class _DayListTabState extends State<_DayListTab> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;

  late DateTime _day = _today();
  String? _userId;
  List<Employee> _employees = const [];

  final List<AttendanceRecord> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  static DateTime _today() {
    final n = nowProvider();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _day == _today();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadFirstPage();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = (await context.read<EmployeeRepository>().list(pageSize: 100)).items;
      if (mounted) setState(() => _employees = list);
    } on ApiException {
      // Chỉ để lọc theo người; không có thì vẫn xem được tất cả.
    }
  }

  Future<AttendanceList> _fetch(int page) => context.read<AttendanceRepository>().list(
        from: _day,
        to: _day.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        userId: _userId,
        page: page,
        pageSize: _pageSize,
      );

  Future<void> _loadFirstPage() async {
    final key = (_day, _userId);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _fetch(1);
      if (!mounted || key != (_day, _userId)) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _total = r.total;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (mounted && key == (_day, _userId)) setState(() => _error = e.message);
    } finally {
      if (mounted && key == (_day, _userId)) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final key = (_day, _userId);
    setState(() => _loadingMore = true);
    try {
      final r = await _fetch(_page + 1);
      if (!mounted || key != (_day, _userId)) return;
      setState(() {
        _items.addAll(r.items);
        _total = r.total;
        _page++;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setDay(DateTime d) {
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      _items.clear();
    });
    _loadFirstPage();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2024), lastDate: _today());
    if (picked != null && mounted) _setDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget body;
    if (_loading && _items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(message: _error!, onRetry: _loadFirstPage);
    } else if (_items.isEmpty) {
      body = ListView(children: const [
        SizedBox(height: 80),
        EmptyView(icon: Icons.event_busy_outlined, title: 'Không có lượt chấm công', subtitle: 'Chưa ai chấm công trong ngày này (hoặc theo bộ lọc hiện tại).'),
      ]);
    } else {
      final hasMore = _items.length < _total;
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                Text('Hiển thị ${_items.length}/$_total lượt', key: const Key('list-count'), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                if (hasMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Tải thêm'),
                  ),
              ]),
            );
          }
          return _RecordCard(_items[i]);
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(key: const Key('day-prev'), tooltip: 'Ngày trước', onPressed: () => _setDay(_day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: TextButton(
                  key: const Key('day-title'),
                  onPressed: _pickDay,
                  child: Text(_isToday ? 'Hôm nay, ${formatDay(_day)}' : formatDayWithWeekday(_day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              IconButton(key: const Key('day-next'), tooltip: 'Ngày sau', onPressed: _isToday ? null : () => _setDay(_day.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<String?>(
            key: const Key('filter-employee'),
            initialValue: _userId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhân viên'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tất cả nhân viên')),
              for (final e in _employees) DropdownMenuItem<String?>(value: e.id, child: Text(e.fullName, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() {
                _userId = v;
                _items.clear();
              });
              _loadFirstPage();
            },
          ),
        ),
        Expanded(child: RefreshIndicator(color: AppColors.ink, onRefresh: _loadFirstPage, child: body)),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard(this.r);
  final AttendanceRecord r;

  @override
  Widget build(BuildContext context) {
    final isIn = r.type == AttendanceType.checkIn;
    final status = isIn ? (r.isLate ? 'Đi trễ' : 'Đúng giờ') : (r.isEarlyLeave ? 'Về sớm' : 'Đúng giờ');
    return ItemCard(
      leading: IconBadge(isIn ? Icons.login_rounded : Icons.logout_rounded),
      title: r.userName.isEmpty ? 'Không rõ' : r.userName,
      subtitle: Text('${r.type.label} · ${formatTime(r.time)} · ${r.location}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      trailing: StatusChip(status, r.isOnTime ? AppColors.ok : AppColors.amberDark),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Cách điểm chấm công ${r.distance.round()} m', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      ),
    );
  }
}
