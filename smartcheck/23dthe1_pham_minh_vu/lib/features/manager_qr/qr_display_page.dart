import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/qr_code.dart';
import '../../data/models/work_location.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/qr_repository.dart';
import '../shared/common.dart';

/// "Điểm chấm công": chọn địa điểm, hiện QR động toàn màn hình và đổi mã theo chu kỳ.
/// Nhân viên quét mã này; mã sống ~45 s nên chụp lại màn hình cũng không dùng được.
class QrDisplayPage extends StatefulWidget {
  const QrDisplayPage({super.key});

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> with WidgetsBindingObserver {
  List<WorkLocation>? _locations;
  String? _loadError;
  WorkLocation? _selected;

  QrCodeInfo? _qr;
  String? _qrError;
  bool _fetching = false;

  Timer? _timer;
  // Đếm bằng timer, không phụ thuộc đồng hồ máy.
  int _elapsed = 0; // giây kể từ lần lấy mã *thành công* gần nhất → quyết định mã còn hạn không
  int _sinceTry = 0; // giây kể từ lần gọi API gần nhất → nhịp đổi mã / thử lại

  int get _cycle => AppConfig.qrRefresh.inSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timer bị đóng băng khi app ở nền, quay lại thì mã cũ gần như chắc chắn đã hết hạn.
    if (state == AppLifecycleState.resumed && _selected != null) _refresh();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadError = null;
      _locations = null;
    });
    try {
      final list = (await context.read<LocationRepository>().list()).items;
      if (!mounted) return;
      setState(() => _locations = list);
      if (list.length == 1) _select(list.first);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  void _select(WorkLocation l) {
    setState(() {
      _selected = l;
      _qr = null;
      _qrError = null;
      _elapsed = 0;
      _sinceTry = 0;
    });
    _refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _elapsed++;
      _sinceTry++;
    });
    if (_sinceTry >= _cycle) _refresh();
  }

  Future<void> _refresh() async {
    final loc = _selected;
    if (loc == null || _fetching) return;
    _fetching = true;
    _sinceTry = 0;
    try {
      final qr = await context.read<QrRepository>().current(loc.id);
      if (!mounted || _selected?.id != loc.id) return;
      setState(() {
        _qr = qr;
        _qrError = null;
        _elapsed = 0;
      });
    } on ApiException catch (e) {
      // Giữ mã cũ trên màn hình (nếu còn hạn) và thử lại ở nhịp kế tiếp.
      if (mounted && _selected?.id == loc.id) {
        setState(() => _qrError = e.message);
      }
    } finally {
      _fetching = false;
    }
  }

  void _back() {
    _timer?.cancel();
    setState(() {
      _selected = null;
      _qr = null;
      _qrError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _buildQr(context, _selected!);
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm chấm công', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _buildPicker(),
    );
  }

  Widget _buildPicker() {
    if (_loadError != null) return ErrorView(message: _loadError!, onRetry: _loadLocations);
    final list = _locations;
    if (list == null) return const LoadingView();
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.place_outlined,
        title: 'Chưa có địa điểm',
        subtitle: 'Admin cần tạo địa điểm chấm công trước.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('Chọn địa điểm cần hiển thị mã QR.', style: TextStyle(color: AppColors.textMuted)),
        ),
        for (final l in list) ...[
          ItemCard(
            leading: const IconBadge(Icons.qr_code_2_rounded),
            title: l.name,
            subtitle: Text(l.address ?? 'Bán kính ${l.radiusMeters} m', style: const TextStyle(color: AppColors.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => _select(l),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildQr(BuildContext context, WorkLocation loc) {
    final qr = _qr;
    final expired = qr != null && _elapsed >= qr.ttlSeconds;
    final remaining = (_cycle - _sinceTry).clamp(0, _cycle);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: DialPainter())),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: _locations != null && _locations!.length > 1 ? 'Đổi địa điểm' : 'Quay lại',
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => _locations != null && _locations!.length > 1 ? _back() : Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(qr?.location.isNotEmpty == true ? qr!.location : loc.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _qrCard(qr, expired),
                          const SizedBox(height: 22),
                          if (qr != null && !expired) ...[
                            Text('Đổi mã sau ${remaining}s',
                                key: const Key('qr-countdown'),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: remaining / _cycle,
                                minHeight: 8,
                                backgroundColor: AppColors.inkSoft,
                                color: AppColors.amber,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (_qrError != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_qrError!, style: const TextStyle(color: Colors.white))),
                                ],
                              ),
                            )
                          else
                            Text('Nhân viên mở SmartCheck và quét mã này để chấm công.',
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard(QrCodeInfo? qr, bool expired) {
    const side = 280.0;
    Widget child;
    if (qr == null) {
      child = SizedBox(
        width: side,
        height: side,
        child: Center(
          child: _qrError == null
              ? const CircularProgressIndicator(strokeWidth: 2.6)
              : OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
        ),
      );
    } else {
      child = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: expired ? 0.12 : 1,
            child: QrImageView(
              key: ValueKey(qr.token), // đổi token thì vẽ lại; test cũng đọc token từ key này
              data: qr.token,
              size: side,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          if (expired)
            SizedBox(
              width: side,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_off_outlined, size: 40, color: AppColors.ink),
                  const SizedBox(height: 8),
                  const Text('Mã đã hết hạn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Lấy mã mới')),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}
