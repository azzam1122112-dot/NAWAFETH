import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/user_scoped_prefs.dart';
import '../../../services/providers_api.dart';
import '../../../widgets/profile_wizard_shell.dart';

class ContentStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ContentStep({super.key, required this.onNext, required this.onBack});

  @override
  State<ContentStep> createState() => _ContentStepState();
}

class _ContentStepState extends State<ContentStep> {
  static const String _draftKey = 'provider_content_draft_v1';

  final ScrollController _scrollController = ScrollController();

  final List<SectionContent> sections = [];

  bool _isAddingNew = false;
  int? _editingIndex;

  Timer? _draftTimer;
  bool _loadingFromBackend = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadFromBackendBestEffort();
  }

  Future<void> _loadFromBackendBestEffort() async {
    if (_loadingFromBackend) return;
    setState(() => _loadingFromBackend = true);
    try {
      final profile = await ProvidersApi().getMyProviderProfile();
      if (profile == null) return;
      final raw = profile['content_sections'];
      if (raw is! List || raw.isEmpty) return;
      if (!mounted) return;
      if (sections.isNotEmpty) return;

      final restored = <SectionContent>[];
      for (final item in raw) {
        if (item is! Map) continue;
        restored.add(
          SectionContent(
            title: (item['title'] ?? '').toString(),
            description: (item['description'] ?? '').toString(),
            contentVideos: <XFile>[],
            contentImages: <XFile>[],
          ),
        );
      }
      setState(() {
        sections
          ..clear()
          ..addAll(restored);
      });
      _updateSectionDone();
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) {
        setState(() => _loadingFromBackend = false);
      } else {
        _loadingFromBackend = false;
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final raw = await UserScopedPrefs.getStringScoped(
        prefs,
        _draftKey,
        userId: userId,
      );
      if (raw == null || raw.trim().isEmpty) {
        _updateSectionDone();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _updateSectionDone();
        return;
      }

      final restored = <SectionContent>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final title = (item['title'] ?? '').toString();
        final description = (item['description'] ?? '').toString();
        final mainPath = (item['main_image_path'] ?? '').toString();
        final videoPaths = (item['video_paths'] is List)
            ? (item['video_paths'] as List)
                .map((e) => (e ?? '').toString())
                .where((s) => s.trim().isNotEmpty)
                .toList()
            : <String>[];
        final imagePaths = (item['image_paths'] is List)
            ? (item['image_paths'] as List)
                .map((e) => (e ?? '').toString())
                .where((s) => s.trim().isNotEmpty)
                .toList()
            : <String>[];

        XFile? mainImage;
        if (mainPath.trim().isNotEmpty && File(mainPath).existsSync()) {
          mainImage = XFile(mainPath);
        }

        final videos = <XFile>[];
        for (final p in videoPaths) {
          if (p.trim().isEmpty) continue;
          if (File(p).existsSync()) videos.add(XFile(p));
        }

        final images = <XFile>[];
        for (final p in imagePaths) {
          if (p.trim().isEmpty) continue;
          if (File(p).existsSync()) images.add(XFile(p));
        }

        restored.add(
          SectionContent(
            title: title,
            description: description,
            mainImage: mainImage,
            contentVideos: videos,
            contentImages: images,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        sections
          ..clear()
          ..addAll(restored);
      });
      _updateSectionDone();
    } catch (_) {
      // Best-effort.
      _updateSectionDone();
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = await UserScopedPrefs.readUserId();
        final list = sections
            .map(
              (s) => {
                'title': s.title,
                'description': s.description,
                'main_image_path': s.mainImage?.path,
                'video_paths': s.contentVideos.map((v) => v.path).toList(),
                'image_paths': s.contentImages.map((i) => i.path).toList(),
              },
            )
            .toList(growable: false);
        await UserScopedPrefs.setStringScoped(
          prefs,
          _draftKey,
          jsonEncode(list),
          userId: userId,
        );
      } catch (_) {
        // ignore
      }
    });
  }

  void _updateSectionDone() {
    final done = sections.isNotEmpty;
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_content',
        done,
        userId: userId,
      );
    }).catchError((_) {});
  }

  void _scrollToEditor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startAddSection() {
    setState(() {
      _isAddingNew = true;
      _editingIndex = null;
    });
    _scrollToEditor();
  }

  void _startEditSection(int index) {
    setState(() {
      _isAddingNew = false;
      _editingIndex = index;
    });
    _scrollToEditor();
  }

  void _cancelAddSection() {
    setState(() {
      _isAddingNew = false;
      _editingIndex = null;
    });
    _scheduleDraftSave();
    _updateSectionDone();
  }

  void _saveNewSection(SectionContent section) {
    setState(() {
      sections.add(section);
      _isAddingNew = false;
    });
    _scheduleDraftSave();
    _updateSectionDone();
  }

  void _saveEditedSection(SectionContent section) {
    final index = _editingIndex;
    if (index == null) return;

    setState(() {
      sections[index] = section;
      _editingIndex = null;
    });
    _scheduleDraftSave();
    _updateSectionDone();
  }

  Future<void> _confirmDeleteSection(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'تأكيد الحذف',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'هل أنت متأكد من حذف هذا القسم؟',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'حذف',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      if (_editingIndex == index) {
        setState(() => _editingIndex = null);
      }
      _deleteSection(index);
    }
  }

  void _deleteSection(int index) {
    setState(() {
      sections.removeAt(index);
    });
    _scheduleDraftSave();
    _updateSectionDone();
  }

  void _saveAndContinue() {
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف قسمًا واحدًا على الأقل قبل المتابعة.')),
      );
      return;
    }

    _saveToBackendAndContinue();
  }

  Future<void> _saveToBackendAndContinue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payloadSections = sections
          .map(
            (s) => {
              'title': s.title.trim(),
              'description': s.description.trim(),
              'media_count': s.contentVideos.length + s.contentImages.length + (s.mainImage != null ? 1 : 0),
            },
          )
          .toList(growable: false);

      final updated = await ProvidersApi().updateMyProviderProfile({
        'content_sections': payloadSections,
      });
      if (updated == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ محتوى الخدمات حالياً.')),
        );
        return;
      }
      _scheduleDraftSave();
      _updateSectionDone();
      if (!mounted) return;
      widget.onNext();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ محتوى الخدمات حالياً.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileWizardShell(
      title: 'محتوى خدماتك',
      subtitle: 'نظّم أعمالك في أقسام واضحة تساعد العميل يفهم خبرتك بسرعة.',
      showTopLoader: _loadingFromBackend,
      onBack: widget.onBack,
      onNext: _saveAndContinue,
      nextBusy: _saving,
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoTip(),
                const SizedBox(height: 18),
                for (int i = 0; i < sections.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SectionSummaryCard(
                      index: i,
                      section: sections[i],
                      onTap: () => _startEditSection(i),
                      onDelete: () => _confirmDeleteSection(i),
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isAddingNew || _editingIndex != null)
                            ? null
                            : _startAddSection,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      "إضافة قسم جديد",
                      style: TextStyle(fontFamily: "Cairo"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isAddingNew || _editingIndex != null)
                  NewSectionEditor(
                    initialSection:
                        _editingIndex != null
                            ? sections[_editingIndex!]
                            : null,
                    onCancel: _cancelAddSection,
                    onSave:
                        _editingIndex != null
                            ? _saveEditedSection
                            : _saveNewSection,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTip() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: Colors.deepPurple, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "مثال: قسم لمحتوى فيديو تعريفي، قسم آخر لشرح لوحة التحكم، قسم ثالث يستعرض نتائج وتجارب عملاء.",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 11.5,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

// نموذج بيانات القسم
class SectionContent {
  String title;
  String description;
  XFile? mainImage; // الصورة الرئيسية للقسم
  List<XFile> contentVideos; // فيديوهات هذا القسم
  List<XFile> contentImages; // صور هذا القسم

  SectionContent({
    this.title = '',
    this.description = '',
    this.mainImage,
    List<XFile>? contentVideos,
    List<XFile>? contentImages,
  }) : contentVideos = contentVideos ?? [],
       contentImages = contentImages ?? [];
}

/// كرت مختصر لعرض القسم (عرض فقط)
class _SectionSummaryCard extends StatelessWidget {
  final int index;
  final SectionContent section;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SectionSummaryCard({
    required this.index,
    required this.section,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = section.mainImage != null;
    final videosCount = section.contentVideos.length;
    final imagesCount = section.contentImages.length;
    final totalContent = videosCount + imagesCount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // صورة مصغرة
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  hasImage
                      ? Image.file(
                        File(section.mainImage!.path),
                        fit: BoxFit.cover,
                      )
                      : Container(
                        color: Colors.deepPurple.shade50,
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 10),

          // نصوص + شارات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title.isEmpty ? "عنوان قسم غير محدد" : section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.description.isEmpty
                      ? "وصف قصير للقسم يظهر هنا."
                      : section.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 11.5,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    hasImage
                        ? _chip(icon: Icons.image, label: "صورة رئيسية مضافة")
                        : _chip(
                          icon: Icons.image_not_supported_outlined,
                          label: "بدون صورة رئيسية",
                          color: Colors.grey.shade400,
                        ),
                    _chip(
                      icon: Icons.collections,
                      label:
                          totalContent == 0
                              ? "لا يوجد محتوى"
                              : "$totalContent محتوى ($videosCount فيديو، $imagesCount صورة)",
                      color:
                          totalContent == 0
                              ? Colors.grey.shade400
                              : Colors.deepPurple,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر الحذف صغير على اليسار
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "حذف هذا القسم",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, Color? color}) {
    final c = color ?? Colors.deepPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontFamily: "Cairo", fontSize: 10.5, color: c),
          ),
        ],
      ),
    );
  }
}

/// محرر قسم جديد يُفتح عند الضغط على "إضافة قسم جديد"
class NewSectionEditor extends StatefulWidget {
  final void Function(SectionContent section) onSave;
  final VoidCallback onCancel;
  final SectionContent? initialSection;

  const NewSectionEditor({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.initialSection,
  });

  @override
  State<NewSectionEditor> createState() => _NewSectionEditorState();
}

class _NewSectionEditorState extends State<NewSectionEditor> {
  static const String _editorDraftKey = 'provider_content_editor_draft_v1';

  final picker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  XFile? _mainImage;
  final List<XFile> _videos = [];
  final List<XFile> _images = [];

  Timer? _draftTimer;

  bool get _isEditing => widget.initialSection != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSection;
    _titleController = TextEditingController(
      text: initial?.title.isNotEmpty == true ? initial!.title : '',
    );
    _descController = TextEditingController(
      text: initial?.description.isNotEmpty == true ? initial!.description : '',
    );
    _mainImage = initial?.mainImage;
    if (initial != null) {
      _videos.addAll(initial.contentVideos);
      _images.addAll(initial.contentImages);
    }

    _loadEditorDraftIfNeeded();
    void onChange() {
      _scheduleEditorDraftSave();
    }

    _titleController.addListener(onChange);
    _descController.addListener(onChange);
  }

  Future<void> _loadEditorDraftIfNeeded() async {
    // Only restore draft when creating a new section (not editing an existing one).
    if (_isEditing) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final raw = await UserScopedPrefs.getStringScoped(
        prefs,
        _editorDraftKey,
        userId: userId,
      );
      if (raw == null || raw.trim().isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;

      final title = (data['title'] ?? '').toString();
      final desc = (data['description'] ?? '').toString();
      final mainPath = (data['main_image_path'] ?? '').toString();
      final videoPaths = (data['video_paths'] is List)
          ? (data['video_paths'] as List)
              .map((e) => (e ?? '').toString())
              .where((s) => s.trim().isNotEmpty)
              .toList()
          : <String>[];
      final imagePaths = (data['image_paths'] is List)
          ? (data['image_paths'] as List)
              .map((e) => (e ?? '').toString())
              .where((s) => s.trim().isNotEmpty)
              .toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        if (_titleController.text.trim().isEmpty && title.trim().isNotEmpty) {
          _titleController.text = title;
        }
        if (_descController.text.trim().isEmpty && desc.trim().isNotEmpty) {
          _descController.text = desc;
        }

        if (_mainImage == null && mainPath.trim().isNotEmpty) {
          if (File(mainPath).existsSync()) {
            _mainImage = XFile(mainPath);
          }
        }

        if (_videos.isEmpty) {
          for (final p in videoPaths) {
            if (File(p).existsSync()) _videos.add(XFile(p));
          }
        }
        if (_images.isEmpty) {
          for (final p in imagePaths) {
            if (File(p).existsSync()) _images.add(XFile(p));
          }
        }
      });
    } catch (_) {
      // Best-effort.
    }
  }

  void _scheduleEditorDraftSave() {
    if (_isEditing) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = await UserScopedPrefs.readUserId();
        final data = <String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'main_image_path': _mainImage?.path,
          'video_paths': _videos.map((v) => v.path).toList(),
          'image_paths': _images.map((i) => i.path).toList(),
        };
        await UserScopedPrefs.setStringScoped(
          prefs,
          _editorDraftKey,
          jsonEncode(data),
          userId: userId,
        );
      } catch (_) {
        // ignore
      }
    });
  }

  void _clearEditorDraft() {
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.removeScoped(prefs, _editorDraftKey, userId: userId);
    }).catchError((_) {});
  }

  Future<void> _pickMainImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _mainImage = picked);
      _scheduleEditorDraftSave();
    }
  }

  void _removeMainImage() {
    if (_mainImage == null) return;
    setState(() => _mainImage = null);
    _scheduleEditorDraftSave();
  }

  void _removeVideoAt(int index) {
    if (index < 0 || index >= _videos.length) return;
    setState(() => _videos.removeAt(index));
    _scheduleEditorDraftSave();
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() => _images.removeAt(index));
    _scheduleEditorDraftSave();
  }

  Future<void> _pickVideo({ImageSource source = ImageSource.gallery}) async {
    final picked = await picker.pickVideo(source: source);
    if (picked != null) {
      setState(() => _videos.add(picked));
      _scheduleEditorDraftSave();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _images.add(picked));
      _scheduleEditorDraftSave();
    }
  }

  void _showAttachmentsPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إضافة المرفقات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
              title: const Text(
                'صورة من الألبوم',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
              title: const Text(
                'تصوير صورة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.deepPurple),
              title: const Text(
                'فيديو من الألبوم',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.deepPurple),
              title: const Text(
                'تصوير فيديو',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(source: ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال عنوان واضح للقسم قبل الحفظ.")),
      );
      return;
    }
    final section = SectionContent(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      mainImage: _mainImage,
      contentVideos: List<XFile>.from(_videos),
      contentImages: List<XFile>.from(_images),
    );
    _clearEditorDraft();
    widget.onSave(section);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان للمحرر
          Row(
            children: [
              Icon(
                _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                color: Colors.deepPurple,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isEditing ? "تعديل القسم" : "إضافة قسم محتوى جديد",
                style: const TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // عنوان القسم
          const Text(
            "عنوان القسم",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: "مثال: فيديو عرض رحلة العميل داخل المتجر الإلكتروني",
              hintStyle: const TextStyle(fontFamily: "Cairo", fontSize: 13),
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
            ),
            style: const TextStyle(fontSize: 14, fontFamily: "Cairo"),
          ),
          const SizedBox(height: 10),

          // وصف القسم
          const Text(
            "وصف قصير للقسم",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText:
                  "مثال: فيديو يوضح خطوات استخدام الخدمة من أول زيارة حتى إتمام العملية.",
              hintStyle: const TextStyle(fontFamily: "Cairo", fontSize: 13),
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
            ),
            style: const TextStyle(fontSize: 14, fontFamily: "Cairo"),
          ),
          const SizedBox(height: 14),

          // صورة رئيسية
          const Text(
            "الصورة الرئيسية",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickMainImage,
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: _mainImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Colors.deepPurple,
                        ),
                        SizedBox(height: 6),
                        Text(
                          "اضغط لاختيار صورة رئيسية لهذا القسم",
                          style: TextStyle(
                            fontFamily: "Cairo",
                            fontSize: 12.5,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_mainImage!.path),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: _removeMainImage,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // محتوى الفيديو والصور
          const Text(
            "محتوى القسم (فيديوهات وصور)",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAttachmentsPickerSheet,
              icon: const Icon(Icons.attachment_rounded, color: Colors.white),
              label: const Text(
                "إضافة المرفقات",
                style: TextStyle(color: Colors.white, fontFamily: "Cairo"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (_videos.isNotEmpty || _images.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              "المحتوى المضاف:",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              itemCount: _videos.length + _images.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final isVideo = i < _videos.length;
                final file = isVideo ? _videos[i] : _images[i - _videos.length];
                final name = file.name;
                final removeIndex = isVideo ? i : (i - _videos.length);
                
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      if (isVideo)
                        Container(
                          color: Colors.black87,
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: Icon(
                                  Icons.videocam,
                                  color: Colors.white24,
                                  size: 40,
                                ),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: "Cairo",
                              fontSize: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (isVideo)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.videocam,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            if (isVideo) {
                              _removeVideoAt(removeIndex);
                            } else {
                              _removeImageAt(removeIndex);
                            }
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  "إلغاء",
                  style: TextStyle(fontFamily: "Cairo", color: Colors.black54),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: Text(
                  _isEditing ? "حفظ التعديلات" : "حفظ القسم",
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "Cairo",
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
