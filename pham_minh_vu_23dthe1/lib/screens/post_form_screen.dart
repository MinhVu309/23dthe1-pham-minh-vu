import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../services/current_user_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/error_view.dart';
import '../widgets/safe_network_image.dart';

/// Tạo bài viết (post == null) hoặc sửa bài. Chủ bài do server lấy từ tài khoản đăng nhập nên không có ô nhập tên.
/// Ảnh được chọn từ thư viện, upload qua api/UploadApi rồi mới gửi bài. Thành công thì pop về với [Post] mới nhất.
class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, this.post, this.pickImageOnOpen = false});

  final Post? post;

  /// Mở thư viện ảnh ngay khi vào màn hình (bấm nút ảnh ở ô soạn bài).
  final bool pickImageOnOpen;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  late final TextEditingController _text = TextEditingController(text: widget.post?.content ?? '');
  final _picker = ImagePicker();

  /// URL ảnh đang có của bài (khi sửa); null nếu đã gỡ hoặc bài không có ảnh.
  late String? _existingImage = SafeNetworkImage.isUrl(widget.post?.image) ? widget.post!.image : null;
  XFile? _picked; // ảnh mới chọn, chưa upload
  bool _busy = false;

  bool get _isEdit => widget.post != null;
  bool get _hasImage => _picked != null || _existingImage != null;

  /// Có gì để đăng: có chữ hoặc có ảnh (server chấp nhận bài chỉ có ảnh).
  bool get _canSubmit => !_busy && (_text.text.trim().isNotEmpty || _hasImage);

  bool get _dirty =>
      _picked != null ||
      _text.text.trim() != (widget.post?.content.trim() ?? '') ||
      (_isEdit && _existingImage == null && SafeNetworkImage.isUrl(widget.post!.image));

  @override
  void initState() {
    super.initState();
    if (widget.pickImageOnOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // Thu nhỏ/nén khi chọn để ảnh luôn nhỏ hơn giới hạn 5MB của server
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (file == null || !mounted) return;
      setState(() => _picked = file);
    } catch (_) {
      if (mounted) showSnack(context, 'Không mở được thư viện ảnh', error: true);
    }
  }

  void _removeImage() => setState(() {
        _picked = null;
        _existingImage = null;
      });

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      var imageUrl = _existingImage;
      final picked = _picked;
      if (picked != null) imageUrl = await apiService.uploadImage(picked.path);
      final content = _text.text.trim();

      final Post result;
      if (_isEdit) {
        await apiService.updatePost(widget.post!.id, content: content, image: imageUrl);
        result = await apiService.getPostById(widget.post!.id);
      } else {
        result = await apiService.createPost(content: content, image: imageUrl);
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, '${_isEdit ? 'Sửa' : 'Đăng'} bài thất bại: ${e.message}', error: true);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await confirmDialog(
      context,
      title: 'Bỏ bài viết?',
      message: 'Nội dung bạn vừa nhập sẽ bị mất.',
      confirmText: 'Bỏ',
    );
    if (discard && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.card,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
          ),
          title: Text(_isEdit ? 'Sửa bài viết' : 'Tạo bài viết', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ListenableBuilder(
                  listenable: _text,
                  builder: (_, _) => FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      disabledBackgroundColor: AppColors.buttonGray,
                    ),
                    child: Text(_isEdit ? 'Lưu' : 'Đăng'),
                  ),
                ),
              ),
            ),
          ],
          bottom: _busy
              ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_author(), const SizedBox(height: 12), _textField(), if (_hasImage) _imagePreview()],
                ),
              ),
            ),
            const Divider(),
            SafeArea(
              top: false,
              child: ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.photo_library, color: AppColors.green, size: 28),
                title: Text(_hasImage ? 'Đổi ảnh' : 'Thêm ảnh'),
                onTap: _pickImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _author() {
    // Đang sửa: hiện chủ bài (Admin có thể sửa bài của người khác); đang tạo: hiện tài khoản đang đăng nhập
    if (_isEdit) return _authorRow(widget.post!.userAvatar, widget.post!.userName);
    return ListenableBuilder(
      listenable: currentUser,
      builder: (_, _) => _authorRow(currentUser.profile?.avatarUrl ?? '', currentUser.profile?.displayName ?? ''),
    );
  }

  Widget _authorRow(String avatar, String name) {
    return Row(
      children: [
        AppAvatar(url: avatar, size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? '...' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Row(
                children: [
                  Icon(Icons.public, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Công khai', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textField() {
    return TextField(
      controller: _text,
      enabled: !_busy,
      autofocus: !widget.pickImageOnOpen,
      minLines: 4,
      maxLines: null,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 18),
      decoration: const InputDecoration(
        hintText: 'Bạn đang nghĩ gì?',
        hintStyle: TextStyle(fontSize: 20, color: AppColors.textSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        counterText: '',
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _imagePreview() {
    final picked = _picked;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: picked != null
                ? Image.file(File(picked.path), width: double.infinity, fit: BoxFit.fitWidth)
                : SafeNetworkImage(url: _existingImage, width: double.infinity, fit: BoxFit.fitWidth, placeholderHeight: 200),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: 'Gỡ ảnh',
              onPressed: _busy ? null : _removeImage,
              style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
