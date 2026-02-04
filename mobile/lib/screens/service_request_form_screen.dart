import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/category.dart';
import '../services/providers_api.dart';
import '../services/marketplace_api.dart';

class ServiceRequestFormScreen extends StatefulWidget {
  final String? providerName;
  final String? providerId;
  final int? initialSubcategoryId;
  final String? initialTitle;
  final String? initialDetails;

  const ServiceRequestFormScreen({
    super.key,
    this.providerName,
    this.providerId,
    this.initialSubcategoryId,
    this.initialTitle,
    this.initialDetails,
  });

  @override
  State<ServiceRequestFormScreen> createState() =>
      _ServiceRequestFormScreenState();
}

class _ServiceRequestFormScreenState extends State<ServiceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  
  DateTime? _deadline;
  List<File> _images = [];
  List<File> _videos = [];
  List<File> _files = [];
  String? _audioPath;
  bool _isRecording = false;
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;

  // Data
  List<Category> _categories = [];
  bool _isLoadingCategories = false;
  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final t = (widget.initialTitle ?? '').trim();
    if (t.isNotEmpty) _titleController.text = t;

    final d = (widget.initialDetails ?? '').trim();
    if (d.isNotEmpty) _detailsController.text = d;

    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final categories = await ProvidersApi().getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });

        final initialSubId = widget.initialSubcategoryId;
        if (initialSubId != null) {
          for (final c in categories) {
            final sub = c.subcategories.where((s) => s.id == initialSubId).toList();
            if (sub.isNotEmpty) {
              _selectedCategory = c;
              _selectedSubCategory = sub.first;
              break;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error fetching categories: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _cityController.dispose();
    if (_recorderInitialized) {
      _recorder.closeRecorder();
    }
    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يجب السماح بالوصول للميكروفون")),
        );
        return;
      }

      await _recorder.openRecorder();
      if (!mounted) return;
      setState(() {
        _recorderInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر تهيئة التسجيل الصوتي")),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);
    if (pickedFile != null) {
      setState(() {
        _videos.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _files.add(File(result.files.single.path!));
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_recorderInitialized) {
      await _initRecorder();
      if (!_recorderInitialized) return;
    }

    if (_isRecording) {
      // إيقاف التسجيل
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      // بدء التسجيل
      final directory = Directory.systemTemp;
      final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path);
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );

    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "إضافة مرفق",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.deepPurple),
                  title: const Text("تصوير صورة"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                  title: const Text("اختيار صورة من المعرض"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.deepPurple),
                  title: const Text("تصوير فيديو"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library, color: Colors.deepPurple),
                  title: const Text("اختيار فيديو من المعرض"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file, color: Colors.deepPurple),
                  title: const Text("اختيار ملف"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار القسم الرئيسي')),
      );
      return;
    }

    /*
    if (_selectedCategory!.subcategories.isNotEmpty && _selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار القسم الفرعي')),
      );
      return;
    }
    */
    // Backend requires subcategory. If category has no subs, code might break if we force it.
    // We'll trust the validation logic below.

    final providerId = int.tryParse((widget.providerId ?? '').trim());
    final isTargeted = providerId != null;
    final requestType = isTargeted ? 'normal' : 'competitive';

    if (!isTargeted && _deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تحديد آخر موعد لاستلام العروض")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // If we don't have a subcategory selected, and backend REQUIRES it as an ID... 
      // We are in a bind if the category has no subcategories.
      // But let's assume valid flow -> pick category -> pick subcategory.
      // Or if no subcategories, maybe pass categories ID? 
      // BUT `ServiceRequest` model relates to `SubCategory` usually. 
      // Let's assume subcategory is mandatory for now.
      
      int? subcategoryId = _selectedSubCategory?.id;
      if (subcategoryId == null) {
         // Try to handle categories without subs if any?
         // For now, enforce subcategory selection.
         if (_selectedCategory!.subcategories.isEmpty) {
            // This is a data issue. 
            throw Exception('Selected category has no subcategories');
         }
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار القسم الفرعي')),
         );
         setState(() => _isSubmitting = false);
         return;
      }

      // Note: deadline and attachments are now supported via updated MarketplaceApi.

      final success = await MarketplaceApi().createRequest(
        subcategoryId: subcategoryId,
        title: _titleController.text,
        description: _detailsController.text,
        city: _cityController.text,
        requestType: requestType,
        providerId: providerId,
        images: _images,
        videos: _videos,
        files: _files,
        audioPath: _audioPath,
      );

      if (!success) {
        throw Exception('تعذر إرسال الطلب');
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.green, size: 30),
                   SizedBox(width: 10),
                   Text("تم إرسال الطلب"),
                ],
              ),
              content: const Text(
                "تم إرسال طلب الخدمة بنجاح.",
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  child: const Text("حسناً"),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الطلب: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Colors.deepPurple;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: mainColor,
          title: Text(
            widget.providerName != null
                ? "طلب خدمة من ${widget.providerName}"
                : "طلب خدمة جديدة",
            style: const TextStyle(fontFamily: "Cairo"),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 🟪 الأقسام والمدينة
              if (_isLoadingCategories)
                const Center(child: CircularProgressIndicator())
              else ...[
                // القسم الرئيسي
                 const Text("القسم الرئيسي", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                 const SizedBox(height: 8),
                 DropdownButtonFormField<Category>(
                  value: _selectedCategory,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubCategory = null; 
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "اختر القسم",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // القسم الفرعي
                if (_selectedCategory != null && _selectedCategory!.subcategories.isNotEmpty) ...[
                 const Text("القسم الفرعي", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                 const SizedBox(height: 8),
                 DropdownButtonFormField<SubCategory>(
                    value: _selectedSubCategory,
                    items: _selectedCategory!.subcategories
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubCategory = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "اختر التخصص",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // المدينة
                const Text("المدينة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: "حدد المدينة",
                    filled: true,
                     fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? "المدينة مطلوبة" : null,
                ),
                const SizedBox(height: 20),
              ],


              // 🟪 عنوان الطلب
              const Text(
                "عنوان الطلب",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: "اكتب عنوان الطلب...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterText: "${_titleController.text.length}/50",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "يرجى إدخال عنوان الطلب";
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // لتحديث العداد
                },
              ),
              const SizedBox(height: 20),

              // 🟪 تفاصيل الطلب
              const Text(
                "تفاصيل الطلب",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                maxLength: 500,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "اكتب تفاصيل الطلب بشكل دقيق...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterText: "${_detailsController.text.length}/500",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "يرجى إدخال تفاصيل الطلب";
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // لتحديث العداد
                },
              ),
              const SizedBox(height: 20),

              // 🟪 آخر موعد لاستلام العروض
              const Text(
                "آخر موعد لاستلام العروض",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDeadline,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: mainColor),
                      const SizedBox(width: 12),
                      Text(
                        _deadline == null
                            ? "اضغط لتحديد التاريخ"
                            : "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}",
                        style: TextStyle(
                          fontSize: 15,
                          color: _deadline == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🟪 المرفقات
              const Text(
                "المرفقات",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // عرض المرفقات المضافة
              if (_images.isNotEmpty || _videos.isNotEmpty || _files.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الصور
                      if (_images.isNotEmpty) ...[
                        const Text(
                          "الصور:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _images.map((image) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    image,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _images.remove(image);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // الفيديوهات
                      if (_videos.isNotEmpty) ...[
                        const Text(
                          "الفيديوهات:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._videos.map((video) {
                          return ListTile(
                            leading: const Icon(
                              Icons.video_file,
                              color: mainColor,
                            ),
                            title: Text(
                              video.path.split('/').last,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _videos.remove(video);
                                });
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                      ],

                      // الملفات
                      if (_files.isNotEmpty) ...[
                        const Text(
                          "الملفات:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._files.map((file) {
                          return ListTile(
                            leading: const Icon(
                              Icons.attach_file,
                              color: mainColor,
                            ),
                            title: Text(
                              file.path.split('/').last,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _files.remove(file);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // زر إضافة مرفق
              ElevatedButton.icon(
                onPressed: _showAttachmentOptions,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "إضافة مرفق",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🟪 تسجيل رسالة صوتية
              const Text(
                "رسالة صوتية (اختياري)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _toggleRecording,
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            size: 40,
                          ),
                          color: _isRecording ? Colors.red : mainColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRecording
                              ? "جاري التسجيل... اضغط للإيقاف"
                              : _audioPath != null
                                  ? "تم التسجيل ✓"
                                  : "اضغط للبدء بالتسجيل",
                          style: TextStyle(
                            fontSize: 14,
                            color: _isRecording ? Colors.red : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    if (_audioPath != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _audioPath = null;
                          });
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text("حذف التسجيل"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 🟪 أزرار التقديم والإلغاء
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text(
                        "تقديم الطلب",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: mainColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "إلغاء",
                        style: TextStyle(
                          fontSize: 16,
                          color: mainColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
