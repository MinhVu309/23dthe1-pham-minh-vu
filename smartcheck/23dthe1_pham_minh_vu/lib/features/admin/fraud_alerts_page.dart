import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models/fraud_alert.dart';
import '../../data/repositories/fraud_repository.dart';
import '../shared/common.dart';

enum _Filter {
  open('Chưa xử lý', false),
  done('Đã xử lý', true),
  all('Tất cả', null);

  const _Filter(this.label, this.resolved);
  final String label;
  final bool? resolved;
}

final _timeFmt = DateFormat('HH:mm dd/MM/yyyy');

/// Cảnh báo gian lận do server ghi lại (GPS giả, máy lạ, di chuyển bất thường, khuôn mặt không khớp...).
/// Admin và Manager đánh dấu đã xử lý.
class FraudAlertsPage extends StatefulWidget {
  const FraudAlertsPage({super.key});

  @override
  State<FraudAlertsPage> createState() => _FraudAlertsPageState();
}

class _FraudAlertsPageState extends State<FraudAlertsPage> {
  _Filter _filter = _Filter.open;
  List<FraudAlert>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<FraudRepository>();
    setState(() {
      _loading = _items == null;
      _error = null;
    });
    try {
      final items = await repo.list(resolved: _filter.resolved);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(FraudAlert a) async {
    final repo = context.read<FraudRepository>();
    if (await guard(context, () => repo.resolve(a.id), success: 'Đã đánh dấu đã xử lý')) await _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items == null) {
      body = ErrorView(message: _error!, onRetry: _load);
    } else if (_items!.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 80),
        EmptyView(
          icon: Icons.verified_user_outlined,
          title: _filter == _Filter.open ? 'Không có cảnh báo nào cần xử lý' : 'Không có cảnh báo',
          subtitle: 'Cảnh báo xuất hiện khi hệ thống phát hiện GPS giả, máy lạ hoặc di chuyển bất thường.',
        ),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _AlertCard(_items![i], onResolve: () => _resolve(_items![i])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo gian lận', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          const SizedBox(height: 4),
          FilterChips<_Filter>(
            options: _Filter.values,
            selected: _filter,
            labelOf: (f) => f.label,
            onChanged: (f) {
              if (f == _filter) return;
              setState(() => _filter = f);
              _load();
            },
          ),
          const SizedBox(height: 8),
          Expanded(child: RefreshIndicator(color: AppColors.ink, onRefresh: _load, child: body)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(this.alert, {required this.onResolve});

  final FraudAlert alert;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    return ItemCard(
      leading: IconBadge(a.resolved ? Icons.check_circle_outline_rounded : Icons.gpp_maybe_outlined, color: a.resolved ? AppColors.ok : AppColors.danger),
      title: a.reason,
      subtitle: Text('${a.userName.isEmpty ? 'Không rõ' : a.userName} · ${_timeFmt.format(a.createdAt)}', style: const TextStyle(color: AppColors.textMuted)),
      trailing: StatusChip(a.resolved ? 'Đã xử lý' : 'Chưa xử lý', a.resolved ? AppColors.ok : AppColors.danger),
      footer: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.detail != null && a.detail!.isNotEmpty)
              Text(a.detail!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
            if (!a.resolved)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: onResolve, icon: const Icon(Icons.check_rounded), label: const Text('Đã xử lý')),
              ),
          ],
        ),
      ),
    );
  }
}
