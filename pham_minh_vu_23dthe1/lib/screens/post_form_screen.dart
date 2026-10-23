import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';

/// Màn hình "Tạo bài viết" (post == null) hoặc sửa bài viết (mở lại form với dữ liệu cũ).
/// Thành công thì pop về với thông điệp (String).
class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, this.post});

  final Post? post;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  // Avatar mặc định cho bài mới (app chưa có đăng nhập)
  static const _defaultAvatar = 'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userName;
  late final TextEditingController _content;
  late final TextEditingController _image;
  bool _saving = false;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _userName = TextEditingController(text: p?.userName ?? 'Phạm Minh Vũ');
    _content = TextEditingController(text: p?.content ?? '');
    _image = TextEditingController(text: p?.image ?? '');
  }

  @override
  void dispose() {
    _userName.dispose();
    _content.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // PUT: giữ nguyên Id, avatar, like, comment, chỉ đổi phần người dùng sửa
        await apiService.updatePost(widget.post!.copyWith(
          userName: _userName.text.trim(),
          content: _content.text.trim(),
          image: _image.text.trim(),
        ));
      } else {
        await apiService.addPost(Post(
          userName: _userName.text.trim(),
          userAvatar: _defaultAvatar,
          content: _content.text.trim(),
          image: _image.text.trim(),
          createdAt: DateTime.now(), // server sẽ ghi đè bằng giờ của nó
        ));
      }
      if (!mounted) return;
      Navigator.pop(context, _isEdit ? 'Đã cập nhật bài viết' : 'Đã đăng bài viết');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, '${_isEdit ? 'Sửa' : 'Đăng'} bài thất bại: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa bài viết' : 'Tạo bài viết'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'LƯU' : 'ĐĂNG'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _userName,
              decoration: const InputDecoration(labelText: 'Tên người đăng', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _content,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Bạn đang nghĩ gì?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nội dung không được để trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _image,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link ảnh (https://..., có thể bỏ trống)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_saving) const Padding(padding: EdgeInsets.only(top: 24), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
