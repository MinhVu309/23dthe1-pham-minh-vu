import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/current_user_store.dart';
import '../theme/app_theme.dart';
import 'app_avatar.dart';
import 'comment_tile.dart';
import 'error_view.dart';

/// Mở bottom sheet bình luận (kéo lên/xuống được). [onCountChanged] nhận +1/-1 khi thêm/xóa bình luận
/// để số bình luận trên thẻ bài viết đổi theo.
Future<void> showCommentSheet(
  BuildContext context, {
  required Post post,
  required void Function(int delta) onCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      // Đẩy cả sheet lên khi bàn phím mở để ô nhập luôn nằm trên bàn phím
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _CommentSheet(
          post: post,
          scrollController: scrollController,
          onCountChanged: onCountChanged,
        ),
      ),
    ),
  );
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.post, required this.scrollController, required this.onCountChanged});

  final Post post;
  final ScrollController scrollController;
  final void Function(int delta) onCountChanged;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  static const _pageSize = 50;

  final _input = TextEditingController();
  final List<Comment> _comments = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _loadError;
  String? _notice; // lỗi khi gửi/xóa (SnackBar sẽ nằm dưới sheet nên hiện ngay trong sheet)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await apiService.getComments(widget.post.id, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _comments.length ~/ _pageSize + 1;
      final page = await apiService.getComments(widget.post.id, page: nextPage, pageSize: _pageSize);
      if (!mounted) return;
      final existing = _comments.map((c) => c.id).toSet();
      setState(() {
        _comments.addAll(page.items.where((c) => !existing.contains(c.id)));
        _total = page.total;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = e.message;
        _loadingMore = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      final comment = await apiService.addComment(widget.post.id, text);
      if (!mounted) return;
      setState(() {
        _comments.add(comment);
        _total += 1;
        _sending = false;
        _input.clear();
      });
      widget.onCountChanged(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (mounted && widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = 'Không gửi được bình luận: ${e.message}';
        _sending = false;
      });
    }
  }

  Future<void> _delete(Comment comment) async {
    final ok = await confirmDialog(context, title: 'Xóa bình luận', message: 'Bạn có chắc muốn xóa bình luận này?');
    if (!ok || !mounted) return;
    try {
      await apiService.deleteComment(widget.post.id, comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _total = (_total - 1).clamp(0, 1 << 30);
        _notice = null;
      });
      widget.onCountChanged(-1);
    } on ApiException catch (e) {
      if (mounted) setState(() => _notice = 'Không xóa được bình luận: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Bình luận', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        const Divider(),
        Expanded(child: _body()),
        if (_notice != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFDECEA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_notice!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        const Divider(),
        _inputBar(),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có bình luận nào.\nHãy là người đầu tiên bình luận!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _comments.length + (_comments.length < _total ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _comments.length) {
          return Center(
            child: TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(_loadingMore ? 'Đang tải...' : 'Xem thêm bình luận (${_total - _comments.length})'),
            ),
          );
        }
        return CommentTile(comment: _comments[i], onDelete: () => _delete(_comments[i]));
      },
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ListenableBuilder(
              listenable: currentUser,
              builder: (_, _) => AppAvatar(url: currentUser.profile?.avatarUrl, size: 32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Viết bình luận...',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Gửi bình luận',
              onPressed: _input.text.trim().isEmpty || _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
