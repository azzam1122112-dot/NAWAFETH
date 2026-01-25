import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'service_request_form_screen.dart'; // ✅ نموذج طلب الخدمة

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final bool isOnline;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.isOnline,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _timer;

  String? _pendingType;
  dynamic _pendingFile;
  int? _pendingDuration;

  // ✅ رسائل مبدئية وهمية (من العميل والمستخدم)
  final List<Map<String, dynamic>> messages = [
    {
      "type": "text",
      "text": "السلام عليكم، عندي استفسار بخصوص العقد.",
      "isMe": false,
      "time": "10:20 ص",
    },
    {
      "type": "text",
      "text": "وعليكم السلام ورحمة الله، تفضل 🌹",
      "isMe": true,
      "time": "10:21 ص",
    },
    {
      "type": "text",
      "text": "هل تقدر تراجع البند الثالث؟",
      "isMe": false,
      "time": "10:22 ص",
    },
  ];

  // ✅ إرسال الرسالة النهائية
  void _sendMessage() {
    if ((_pendingType == null || _pendingType == "text") &&
        _controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      messages.add({
        "type": _pendingType ?? "text",
        "text":
            _controller.text.trim().isEmpty ? null : _controller.text.trim(),
        "file": _pendingFile,
        "isMe": true,
        "time": TimeOfDay.now().format(context),
        "duration": _pendingType == "audio" ? _pendingDuration : null,
      });
      _pendingType = null;
      _pendingFile = null;
      _pendingDuration = null;
      _controller.clear();
      _recordSeconds = 0;
    });
  }

  // ✅ التسجيل
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _pendingType = null;
      _pendingFile = null;
      _recordSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordSeconds++);
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _pendingType = "audio";
      _pendingDuration = _recordSeconds;
    });
  }

  // ✅ اختيار صورة من المعرض
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pendingType = "image";
        _pendingFile = File(picked.path);
      });
    }
  }

  // ✅ تصوير صورة من الكاميرا
  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _pendingType = "image";
        _pendingFile = File(picked.path);
      });
    }
  }

  // ✅ اختيار ملف
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pendingType = "file";
        _pendingFile = File(result.files.single.path!);
      });
    }
  }

  // ✅ تسجيل فيديو (بحد أقصى 3 دقائق)
  Future<void> _recordVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked != null) {
      setState(() {
        _pendingType = "video";
        _pendingFile = File(picked.path);
      });
    }
  }

  // ✅ اختيار فيديو من المعرض
  Future<void> _pickVideoFromGallery() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (picked != null) {
      setState(() {
        _pendingType = "video";
        _pendingFile = File(picked.path);
      });
    }
  }

  // ✅ خيارات المرفقات
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (_) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.deepPurple),
                title: const Text(
                  "اختيار صورة من المعرض",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                title: const Text(
                  "تصوير صورة",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.videocam,
                  color: Colors.deepPurple,
                ),
                title: const Text(
                  "تسجيل فيديو (حد أقصى 3 دقائق)",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _recordVideo();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.video_library,
                  color: Colors.deepPurple,
                ),
                title: const Text(
                  "اختيار فيديو من المعرض",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.deepPurple,
                ),
                title: const Text(
                  "اختيار ملف",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
    );
  }

  // ✅ خيارات المحادثة من الشريط العلوي
  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.mark_chat_read, color: Colors.blue),
            title: const Text(
              "اجعلها مقروءة",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم تمييز المحادثة كمقروءة",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text(
              "مفضلة",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تمت إضافة المحادثة للمفضلة",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.label, color: Colors.green),
            title: const Text(
              "تمييز كعميل",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم تمييز المحادثة كعميل",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text(
              "حظر العضو",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              _showBlockConfirmation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.orange),
            title: const Text(
              "الإبلاغ عن عضو",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              _showReportDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              "حذف المحادثة",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation();
            },
          ),
        ],
      ),
    );
  }

  // ✅ تأكيد الحظر
  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "حظر العضو",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Text(
          "هل أنت متأكد من حظر ${widget.name}؟ \n\nلن يتمكن من مراسلتك بعد ذلك.",
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "إلغاء",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم حظر العضو بنجاح",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              "حظر",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تأكيد حذف المحادثة
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "حذف المحادثة",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "هل أنت متأكد من حذف هذه المحادثة؟ \n\nلن تتمكن من استرجاعها بعد ذلك.",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "إلغاء",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => messages.clear());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم حذف المحادثة",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              "حذف",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ إرسال رابط طلب خدمة للعميل
  void _sendServiceRequestLink() {
    setState(() {
      messages.add({
        "type": "service_request",
        "text": "يمكنك طلب خدمة من خلال الضلغط على الزر أدناه",
        "isMe": true,
        "time": TimeOfDay.now().format(context),
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم إرسال رابط طلب الخدمة للعميل",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  // ✅ الانتقال إلى صفحة طلب الخدمة
  void _goToServiceRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestFormScreen(
          providerName: widget.name,
          providerId: null, // يمكن تمرير ID مقدم الخدمة إذا كان متاحاً
        ),
      ),
    );
  }

  // ✅ عرض طلبات العميل
  void _showClientOrders() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مقبض السحب
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // عنوان
              Row(
                children: [
                  const Icon(
                    Icons.assignment,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "طلبات ${widget.name}",
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "الطلبات الحالية والسابقة",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // قائمة الطلبات
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _orderCard(
                      title: "مراجعة عقد عمل",
                      status: "جاري",
                      date: "2025-12-25",
                      price: "500 ر.س",
                      statusColor: Colors.orange,
                    ),
                    _orderCard(
                      title: "استشارة قانونية",
                      status: "مكتمل",
                      date: "2025-12-20",
                      price: "300 ر.س",
                      statusColor: Colors.green,
                    ),
                    _orderCard(
                      title: "صياغة عقد شراكة",
                      status: "مكتمل",
                      date: "2025-11-15",
                      price: "800 ر.س",
                      statusColor: Colors.green,
                    ),
                    _orderCard(
                      title: "مراجعة وثيقة قانونية",
                      status: "ملغي",
                      date: "2025-10-10",
                      price: "200 ر.س",
                      statusColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ كرت طلب
  Widget _orderCard({
    required String title,
    required String status,
    required String date,
    required String price,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                price,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ نموذج الإبلاغ
  void _showReportDialog() {
    String? selectedReason;
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            "إبلاغ عن المحادثة",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "المستخدم:",
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.name,
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 16),
                const Text(
                  "سبب الإبلاغ:",
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: const Text(
                    "اختر السبب",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  items: [
                    "محتوى غير لائق",
                    "تحرش أو إزعاج",
                    "احتيال أو نصب",
                    "محتوى مسيء",
                    "انتهاك الخصوصية",
                    "أخرى",
                  ]
                      .map((reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(
                              reason,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedReason = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  "تفاصيل إضافية (اختياري):",
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "أضف تفاصيل إضافية...",
                    hintStyle: TextStyle(fontFamily: 'Cairo'),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "إلغاء",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedReason != null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم إرسال البلاغ بنجاح",
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "يرجى اختيار سبب الإبلاغ",
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text(
                "إرسال",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ خيارات الرسالة
  void _showMessageOptions(Map<String, dynamic> msg) {
    final isMe = msg["isMe"] ?? false;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Wrap(
        children: [
          if (!isMe) ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text(
                "إبلاغ عن هذه الرسالة",
                style: TextStyle(fontFamily: "Cairo"),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportMessageDialog(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text(
                "حظر المرسل",
                style: TextStyle(fontFamily: "Cairo"),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "تم حظر المستخدم بنجاح",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.deepPurple),
            title: const Text(
              "نسخ النص",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              Navigator.pop(context);
              if (msg["text"] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "تم نسخ النص",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              "حذف الرسالة",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            onTap: () {
              setState(() => messages.remove(msg));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ✅ نموذج الإبلاغ عن رسالة
  void _showReportMessageDialog(Map<String, dynamic> msg) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = "محتوى غير لائق";
    
    final reasons = [
      "محتوى غير لائق",
      "احتيال أو نصب",
      "إزعاج أو مضايقة",
      "محتوى مخالف للشروط",
      "أخرى",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.report,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "إبلاغ عن رسالة",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // محتوى الرسالة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.name,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "محتوى الرسالة:",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg["text"] ?? msg["type"] ?? "",
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الوقت: ${msg["time"]}",
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    "سبب الإبلاغ:",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        items: reasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(
                              reason,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedReason = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    "تفاصيل إضافية (اختياري):",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: "اكتب التفاصيل هنا...",
                      hintStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "إلغاء",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم إرسال البلاغ للإدارة. شكراً لك",
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "إرسال البلاغ",
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ فقاعة الرسائل
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg["isMe"] ?? false;
    final type = msg["type"];
    final file = msg["file"];

    Color bubbleColor = isMe ? Colors.deepPurple : Colors.grey.shade200;
    Color textColor = isMe ? Colors.white : Colors.black87;

    Widget content;

    if (type == "text") {
      content = Text(
        msg["text"] ?? "",
        style: TextStyle(color: textColor, fontFamily: "Cairo", fontSize: 15),
      );
    } else if (type == "image") {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, width: 200, fit: BoxFit.cover),
      );
    } else if (type == "file") {
      final f = file as File;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              f.path.split('/').last,
              style: TextStyle(color: textColor, fontFamily: "Cairo"),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (type == "video") {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 50,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'فيديو',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: "Cairo",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (type == "audio") {
      final duration = msg["duration"] ?? 0;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill, color: textColor, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "رسالة صوتية (${_formatDuration(duration)})",
              style: TextStyle(color: textColor, fontFamily: "Cairo"),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (type == "service_request") {
      // ✅ رسالة خاصة لطلب الخدمة
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.deepPurple.shade100 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_offer,
                      color: isMe ? Colors.deepPurple : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msg["text"] ?? "طلب خدمة",
                        style: TextStyle(
                          color: isMe ? Colors.deepPurple.shade900 : Colors.blue.shade900,
                          fontFamily: "Cairo",
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _goToServiceRequest(),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text(
                      "طلب خدمة الآن",
                      style: TextStyle(
                        fontFamily: "Cairo",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = const Text("❓");
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              content,
              const SizedBox(height: 5),
              Text(
                msg["time"],
                style: TextStyle(
                  fontSize: 11,
                  color: isMe ? Colors.white70 : Colors.black54,
                  fontFamily: "Cairo",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ معاينة قبل الإرسال
  Widget _buildPreview() {
    if (_pendingType == "image" && _pendingFile != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _pendingFile,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed:
                () => setState(() {
                  _pendingType = null;
                  _pendingFile = null;
                }),
          ),
        ],
      );
    } else if (_pendingType == "file" && _pendingFile != null) {
      return Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.deepPurple),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              (_pendingFile as File).path.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: "Cairo"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed:
                () => setState(() {
                  _pendingType = null;
                  _pendingFile = null;
                }),
          ),
        ],
      );
    } else if (_pendingType == "audio" && _pendingDuration != null) {
      return Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "رسالة صوتية (${_formatDuration(_pendingDuration!)})",
              style: const TextStyle(fontFamily: "Cairo"),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed:
                () => setState(() {
                  _pendingType = null;
                  _pendingDuration = null;
                }),
          ),
        ],
      );
    } else if (_pendingType == "video" && _pendingFile != null) {
      return Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "فيديو جاهز للإرسال",
              style: TextStyle(fontFamily: "Cairo"),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed:
                () => setState(() {
                  _pendingType = null;
                  _pendingFile = null;
                }),
          ),
        ],
      );
    } else {
      return TextField(
        controller: _controller,
        style: const TextStyle(fontFamily: "Cairo"),
        decoration: const InputDecoration(
          hintText: "اكتب رسالة...",
          border: InputBorder.none,
        ),
        onChanged:
            (_) => setState(() {
              _pendingType = "text";
            }),
      );
    }
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.deepPurple,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple.shade200,
              child: Text(
                widget.name[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.isOnline ? "متصل الآن" : "غير متصل",
                    style: const TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // ✅ أيقونة عرض طلبات العميل
            IconButton(
              icon: const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => _showClientOrders(),
              tooltip: "طلبات العميل",
            ),
            // ✅ أيقونة إرسال رابط طلب خدمة
            IconButton(
              icon: const Icon(
                Icons.send_outlined,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => _sendServiceRequestLink(),
              tooltip: "إرسال رابط طلب خدمة",
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ الرسائل
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: messages.length,
              itemBuilder:
                  (context, index) => _buildMessageBubble(messages[index]),
            ),
          ),

          // ✅ شريط الإدخال
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: Colors.deepPurple,
                    ),
                    onPressed: _showAttachmentOptions,
                  ),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child:
                          _isRecording
                              ? Row(
                                children: [
                                  const Icon(Icons.mic, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: (_recordSeconds % 10) / 10,
                                      color: Colors.red,
                                      backgroundColor: Colors.red.shade100,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatDuration(_recordSeconds),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              )
                              : _buildPreview(),
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (_isRecording)
                    CircleAvatar(
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: const Icon(Icons.stop, color: Colors.white),
                        onPressed: _stopRecording,
                      ),
                    )
                  else
                    CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: IconButton(
                        icon: const Icon(Icons.mic, color: Colors.white),
                        onPressed: _startRecording,
                      ),
                    ),
                  const SizedBox(width: 8),

                  CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
