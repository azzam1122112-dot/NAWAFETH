import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/colors.dart';
import '../../models/provider_portfolio_item.dart';
import '../../services/providers_api.dart';
import '../network_video_player_screen.dart';

class ProviderPortfolioManageScreen extends StatefulWidget {
  const ProviderPortfolioManageScreen({super.key});

  @override
  State<ProviderPortfolioManageScreen> createState() =>
      _ProviderPortfolioManageScreenState();
}

class _ProviderPortfolioManageScreenState
    extends State<ProviderPortfolioManageScreen> {
  bool _loading = true;
  bool _saving = false;
  List<ProviderPortfolioItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await ProvidersApi().getMyPortfolio();
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _close() {
    Navigator.pop<bool>(context, _items.isNotEmpty);
  }

  String _detectFileType(String name) {
    final lower = name.toLowerCase();
    const videoExt = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm',
      '.m4v',
    ];
    for (final ext in videoExt) {
      if (lower.endsWith(ext)) return 'video';
    }
    return 'image';
  }

  Future<void> _createFromFile(PlatformFile file, {required String caption}) async {
    if (_saving) return;
    final fileType = _detectFileType(file.name);
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final created = await ProvidersApi().createMyPortfolioItem(
        file: file,
        fileType: fileType,
        caption: caption,
      );
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الملف')),
        );
        return;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة بنجاح')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage(ImageSource source, {required String caption}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;
    final file = PlatformFile(
      name: picked.name,
      size: await File(picked.path).length(),
      path: picked.path,
    );
    await _createFromFile(file, caption: caption);
  }

  Future<void> _pickFile({required String caption}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'png', 'jpg', 'jpeg', 'webp',
        'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    await _createFromFile(result.files.first, caption: caption);
  }

  Future<void> _showAddDialog() async {
    if (!mounted) return;
    final captionController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.deepPurple, width: 1.2),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: AppColors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'إضافة إلى المعرض',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: captionController,
                  textInputAction: TextInputAction.done,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'شرح بسيط (اختياري)',
                    hintText: 'مثال: قبل/بعد - تصميم واجهة - جزء من مشروع...',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                ListTile(
                  onTap: () async {
                    final caption = captionController.text.trim();
                    Navigator.pop(ctx);
                    await _pickImage(ImageSource.gallery, caption: caption);
                  },
                  title: const Text('اختيار من المعرض', style: TextStyle(fontFamily: 'Cairo')),
                  trailing: const Icon(Icons.photo_library_outlined),
                ),
                ListTile(
                  onTap: () async {
                    final caption = captionController.text.trim();
                    Navigator.pop(ctx);
                    await _pickImage(ImageSource.camera, caption: caption);
                  },
                  title: const Text('التقاط صورة', style: TextStyle(fontFamily: 'Cairo')),
                  trailing: const Icon(Icons.camera_alt_outlined),
                ),
                ListTile(
                  onTap: () async {
                    final caption = captionController.text.trim();
                    Navigator.pop(ctx);
                    await _pickFile(caption: caption);
                  },
                  title: const Text('اختيار ملف', style: TextStyle(fontFamily: 'Cairo')),
                  trailing: const Icon(Icons.folder_open_outlined),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: AppColors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProviderPortfolioItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'حذف من المعرض',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'هل تريد حذف هذا العنصر؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final ok = await ProvidersApi().deleteMyPortfolioItem(item.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف العنصر')),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الحذف')),
    );
  }

  Future<void> _openItem(ProviderPortfolioItem item) async {
    final url = item.fileUrl.trim();
    if (url.isEmpty) return;

    if (item.fileType.toLowerCase() == 'video') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NetworkVideoPlayerScreen(
            url: url,
            title: 'معرض الخدمات',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 52),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _close();
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.deepPurple,
            foregroundColor: Colors.white,
            title: const Text('معرض الخدمات', style: TextStyle(fontFamily: 'Cairo')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _close,
            ),
            actions: [
              IconButton(
                tooltip: 'إضافة',
                onPressed: _saving ? null : _showAddDialog,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.deepPurple),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 52, color: AppColors.deepPurple),
                            const SizedBox(height: 10),
                            const Text(
                              'لا يوجد محتوى في المعرض بعد',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أضف صور أو فيديوهات لأعمالك لزيادة ثقة العملاء.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _showAddDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        itemCount: _items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final url = item.fileUrl.trim();
                          final isVideo = item.fileType.toLowerCase() == 'video';
                          final caption = item.caption.trim();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _openItem(item),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            color: Colors.grey.shade200,
                                            child: url.isEmpty
                                                ? const Center(child: Icon(Icons.broken_image_outlined))
                                                : Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image_outlined),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      if (isVideo)
                                        const Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                                        ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: InkWell(
                                          onTap: () => _confirmDelete(item),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.45),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (caption.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
