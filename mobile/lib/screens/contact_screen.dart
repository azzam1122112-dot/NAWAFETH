import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../core/permissions/permissions_service.dart';
import '../models/ticket_model.dart';
import '../services/notifications_badge_controller.dart';
import '../services/support_api.dart';

class ContactScreen extends StatefulWidget {
  final bool startNewTicketForm;
  final String? initialSupportTeam;
  final String? initialDescription;
  final int? initialTicketId;

  const ContactScreen({
    super.key,
    this.startNewTicketForm = false,
    this.initialSupportTeam,
    this.initialDescription,
    this.initialTicketId,
  });

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final SupportApi _supportApi = SupportApi();
  bool _isFeatureActionInProgress = false;
  bool _isLoadingTickets = false;
  Timer? _liveRefreshTimer;
  int? _lastUnreadCount;

  // لا توجد بيانات محلية وهمية؛ يجب أن تأتي التذاكر من API الدعم.
  List<Ticket> tickets = [];

  Ticket? selectedTicket;
  bool showNewTicketForm = false;
  bool isSupportTeamDropdownOpen = false;
  
  // متحكمات النموذج
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  String? selectedSupportTeam;
  List<String> attachments = [];

  // قوائم فرق الدعم من الباكند
  List<String> supportTeams = const [];
  final Map<String, String> _teamNameToCode = <String, String>{};
  final Map<String, String> _teamCodeToName = <String, String>{};

  @override
  void initState() {
    super.initState();

    if (widget.startNewTicketForm) {
      showNewTicketForm = true;
      selectedTicket = null;
    }

    final desc = widget.initialDescription;
    if (desc != null && desc.trim().isNotEmpty) {
      _descriptionController.text = desc;
    }
    _bootstrapSupportData();
    NotificationsBadgeController.instance.unreadNotifier.addListener(_onUnreadChanged);
    _lastUnreadCount = NotificationsBadgeController.instance.unreadNotifier.value;
    _startLiveRefresh();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    NotificationsBadgeController.instance.unreadNotifier.removeListener(_onUnreadChanged);
    _descriptionController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _loadTickets(silent: true);
    });
  }

  void _onUnreadChanged() {
    final current = NotificationsBadgeController.instance.unreadNotifier.value;
    final previous = _lastUnreadCount;
    _lastUnreadCount = current;
    if (current == null || previous == null) return;
    if (current <= previous) return;
    _loadTickets(silent: true);
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy - HH:mm').format(dt);
  }

  String _normalizeSupportStatus(String raw) {
    switch (raw.trim()) {
      case 'new':
        return 'جديد';
      case 'in_progress':
        return 'تحت المعالجة';
      case 'returned':
        return 'معاد للعميل';
      case 'closed':
        return 'مغلق';
      default:
        return 'جديد';
    }
  }

  String _statusLabelFromCode(String raw) {
    switch (raw.trim()) {
      case 'new':
        return 'جديد';
      case 'in_progress':
        return 'تحت المعالجة';
      case 'returned':
        return 'معاد للعميل';
      case 'closed':
        return 'مغلق';
      default:
        return raw;
    }
  }

  Ticket _ticketFromApi(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      final s = value?.toString();
      if (s == null || s.trim().isEmpty) return DateTime.now();
      return DateTime.tryParse(s)?.toLocal() ?? DateTime.now();
    }

    final comments = (json['comments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['is_internal'] != true)
        .map(
          (e) => TicketReply(
            from: ((e['created_by_name'] ?? '').toString().trim() == 'منصة نوافذ')
                ? 'platform'
                : 'user',
            message: (e['text'] ?? '').toString(),
            timestamp: parseDate(e['created_at']),
          ),
        )
        .toList();

    final statusReplies = (json['status_logs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((e) {
          final from = _statusLabelFromCode((e['from_status'] ?? '').toString());
          final to = _statusLabelFromCode((e['to_status'] ?? '').toString());
          final note = (e['note'] ?? '').toString().trim();
          final msg = note.isEmpty
              ? 'تم تحديث حالة البلاغ من "$from" إلى "$to".'
              : 'تم تحديث حالة البلاغ من "$from" إلى "$to". الملاحظة: $note';
          return TicketReply(
            from: 'platform',
            message: msg,
            timestamp: parseDate(e['created_at']),
          );
        })
        .toList();

    final allReplies = <TicketReply>[
      ...comments,
      ...statusReplies,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final attachmentsApi = (json['attachments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => (e['file'] ?? '').toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final teamObj = json['assigned_team_obj'];
    String supportTeamName = 'غير محدد';
    if (teamObj is Map) {
      supportTeamName = (teamObj['name_ar'] ?? 'غير محدد').toString();
    } else {
      final typeCode = (json['ticket_type'] ?? '').toString();
      supportTeamName = _teamCodeToName[typeCode] ?? typeCode;
    }

    final code = (json['code'] ?? json['id'] ?? '').toString();
    return Ticket(
      backendId: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      id: code.isEmpty ? '—' : code,
      createdAt: parseDate(json['created_at']),
      status: _normalizeSupportStatus((json['status'] ?? '').toString()),
      supportTeam: supportTeamName,
      title: supportTeamName,
      description: (json['description'] ?? '').toString(),
      attachments: attachmentsApi,
      replies: allReplies,
      lastUpdate: parseDate(json['updated_at']),
    );
  }

  Future<void> _bootstrapSupportData() async {
    await _loadSupportTeams();
    await _loadTickets();
  }

  Future<void> _loadSupportTeams() async {
    try {
      final teams = await _supportApi.getTeams();
      if (!mounted) return;
      setState(() {
        supportTeams = teams
            .map((e) => (e['name_ar'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        _teamNameToCode
          ..clear()
          ..addEntries(
            teams.map((e) {
              final name = (e['name_ar'] ?? '').toString().trim();
              final code = (e['code'] ?? '').toString().trim();
              return MapEntry(name, code);
            }),
          );
        _teamCodeToName
          ..clear()
          ..addEntries(
            teams.map((e) {
              final name = (e['name_ar'] ?? '').toString().trim();
              final code = (e['code'] ?? '').toString().trim();
              return MapEntry(code, name);
            }),
          );
      });

      final initialTeam = widget.initialSupportTeam?.trim();
      if (initialTeam != null && initialTeam.isNotEmpty && mounted) {
        if (supportTeams.contains(initialTeam)) {
          setState(() => selectedSupportTeam = initialTeam);
        }
      }
    } catch (_) {
      // ignore: fallback to empty team list
    }
  }

  Future<void> _loadTickets({bool silent = false}) async {
    if (_isLoadingTickets && silent) return;
    if (!silent) {
      setState(() => _isLoadingTickets = true);
    }
    try {
      final list = await _supportApi.getMyTickets();
      final mapped = list.map(_ticketFromApi).toList();
      if (!mounted) return;
      setState(() {
        tickets = mapped;
        final initialTicketId = widget.initialTicketId;
        if (initialTicketId != null && selectedTicket == null) {
          final targeted = tickets.where((t) => t.backendId == initialTicketId).toList();
          if (targeted.isNotEmpty) {
            selectedTicket = targeted.first;
            showNewTicketForm = false;
          }
        }
        if (selectedTicket != null) {
          final current = tickets.where((t) => t.id == selectedTicket!.id).toList();
          if (current.isNotEmpty) selectedTicket = current.first;
        }
      });
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل تذاكر الدعم')),
      );
    } finally {
      if (mounted && !silent) setState(() => _isLoadingTickets = false);
    }
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'جديد':
        return isDark ? Colors.blue.shade300 : Colors.blue.shade100;
      case 'تحت المعالجة':
        return isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade100;
      case 'معاد للعميل':
        return isDark ? Colors.orange.shade300 : Colors.orange.shade100;
      case 'مغلق':
        return isDark ? Colors.grey.shade400 : Colors.grey.shade300;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status, bool isDark) {
    switch (status) {
      case 'جديد':
        return isDark ? Colors.blue.shade900 : Colors.blue.shade700;
      case 'تحت المعالجة':
        return isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade700;
      case 'معاد للعميل':
        return isDark ? Colors.orange.shade900 : Colors.orange.shade700;
      case 'مغلق':
        return isDark ? Colors.grey.shade900 : Colors.grey.shade700;
      default:
        return isDark ? Colors.grey.shade900 : Colors.grey.shade600;
    }
  }

  Future<void> _pickImage() async {
    final perm = await PermissionsService.ensureGallery();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(perm.messageAr)),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        attachments.add(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final perm = await PermissionsService.ensureCamera();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(perm.messageAr)),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        attachments.add(photo.path);
      });
    }
  }

  Future<void> _pickFile() async {
    final perm = await PermissionsService.ensureFileAccess();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(perm.messageAr)),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        attachments.add(result.files.single.path!);
      });
    }
  }

  Future<void> _sendCurrentLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('إرسال الموقع متاح بعد فتح تذكرة.')),
    );
  }

  Future<void> _createNewTicket() async {
    if (selectedSupportTeam == null || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فريق الدعم وكتابة التفاصيل')),
      );
      return;
    }
    final teamCode = _teamNameToCode[selectedSupportTeam!];
    if (teamCode == null || teamCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد نوع التذكرة من فريق الدعم المختار')),
      );
      return;
    }

    setState(() => _isFeatureActionInProgress = true);
    try {
      final created = await _supportApi.createTicket(
        ticketType: teamCode,
        description: _descriptionController.text.trim(),
      );
      final ticketIdRaw = created['id'];
      final ticketId = ticketIdRaw is int ? ticketIdRaw : int.tryParse('$ticketIdRaw');
      if (ticketId != null) {
        for (final path in attachments) {
          try {
            await _supportApi.addAttachment(ticketId: ticketId, filePath: path);
          } catch (_) {}
        }
      }

      await _loadTickets();
      if (!mounted) return;
      setState(() {
        showNewTicketForm = false;
        _descriptionController.clear();
        selectedSupportTeam = null;
        attachments.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء التذكرة بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إنشاء التذكرة')),
      );
    } finally {
      if (mounted) setState(() => _isFeatureActionInProgress = false);
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty || selectedTicket == null) return;
    final idRaw = selectedTicket!.id.replaceAll(RegExp(r'[^0-9]'), '');
    final ticketId = int.tryParse(idRaw);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد رقم التذكرة')),
      );
      return;
    }

    try {
      await _supportApi.addComment(
        ticketId: ticketId,
        text: _replyController.text.trim(),
      );
      _replyController.clear();
      final detail = await _supportApi.getTicketDetail(ticketId);
      final mapped = _ticketFromApi(detail);
      if (!mounted) return;
      setState(() {
        selectedTicket = mapped;
        final index = tickets.indexWhere((t) => t.id == mapped.id);
        if (index >= 0) {
          tickets[index] = mapped;
        } else {
          tickets.insert(0, mapped);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الرد')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "تواصل مع منصة نوافذ",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // قائمة البلاغات
            _buildTicketsSection(theme, isDark),
            
            const SizedBox(height: 24),

            // نموذج بلاغ جديد أو تفاصيل البلاغ المحدد
            if (showNewTicketForm)
              _buildNewTicketForm(theme, isDark)
            else if (selectedTicket != null)
              _buildTicketDetails(theme, isDark)
            else
              Center(
                child: Text(
                  'اضغط على بلاغ لعرض التفاصيل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsSection(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قائمة البلاغات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showNewTicketForm = true;
                    selectedTicket = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.pink.shade300
                      : const Color(0xFFE1BEE7),
                  foregroundColor: isDark ? Colors.black87 : Colors.deepPurple.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text(
                  'بلاغ جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // عرض البطاقات
          if (_isLoadingTickets)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'لا توجد تذاكر حالياً.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          else
            ...tickets.map((ticket) => _buildTicketCard(ticket, theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, ThemeData theme, bool isDark) {
    final isSelected = selectedTicket?.id == ticket.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTicket = ticket;
          showNewTicketForm = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50)
              : (isDark ? Colors.grey.shade800 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.deepPurple.shade300 : Colors.deepPurple)
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket.status, isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ticket.status,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusTextColor(ticket.status, isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ticket.title,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(ticket.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ticket.id,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.deepPurple.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTicketForm(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رسالة توجيهية
          Row(
            children: [
              Checkbox(
                value: selectedSupportTeam != null,
                onChanged: null,
                activeColor: Colors.deepPurple,
              ),
              Expanded(
                child: Text(
                  'لكي نخدمك بشكل أفضل حدد فريق الدعم المطلوب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // قائمة فرق الدعم
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      isSupportTeamDropdownOpen = !isSupportTeamDropdownOpen;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSupportTeamDropdownOpen 
                              ? Icons.arrow_drop_up 
                              : Icons.arrow_drop_down,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedSupportTeam ?? 'فريق الدعم الفني',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (selectedSupportTeam != null)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                if (isSupportTeamDropdownOpen) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'قائمة متسلسلة:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...supportTeams.map((team) => CheckboxListTile(
                    title: Text(
                      team,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    value: selectedSupportTeam == team,
                    onChanged: (bool? value) {
                      setState(() {
                        selectedSupportTeam = value == true ? team : null;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    activeColor: Colors.deepPurple,
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // حقل التفاصيل
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLength: 300,
              maxLines: 4,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'تفاصيل الطلب (300 حرف)',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // قسم المرفقات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'المرفقات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentButton(
                      icon: Icons.photo_library,
                      label: 'Photo Library',
                      onTap: _pickImage,
                      isDark: isDark,
                    ),
                    _buildAttachmentButton(
                      icon: Icons.camera_alt,
                      label: 'Take Photo',
                      onTap: _takePhoto,
                      isDark: isDark,
                    ),
                    _buildAttachmentButton(
                      icon: Icons.folder,
                      label: 'Choose File',
                      onTap: _pickFile,
                      isDark: isDark,
                    ),
                  ],
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'المرفقات المضافة: ${attachments.length}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isFeatureActionInProgress ? null : _sendCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text(
                      'إرسال موقعي الحالي',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // أزرار الإجراءات
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    showNewTicketForm = false;
                    isSupportTeamDropdownOpen = false;
                    _descriptionController.clear();
                    selectedSupportTeam = null;
                    attachments.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.pink.shade300 : Colors.deepPurple,
                  side: BorderSide(
                    color: isDark ? Colors.pink.shade300 : Colors.deepPurple,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _createNewTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.pink.shade300 : const Color(0xFFE1BEE7),
                  foregroundColor: isDark ? Colors.black87 : Colors.deepPurple.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text(
                  'إرسال',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketDetails(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات البلاغ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(selectedTicket!.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedTicket!.title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  selectedTicket!.id,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // الوصف
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              selectedTicket!.description,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // زر تعديل
          Center(
            child: OutlinedButton(
              onPressed: () {
                // يمكن إضافة وظيفة التعديل
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                side: BorderSide(
                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: const Text(
                'تعديل',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // المرفقات
          if (selectedTicket!.attachments.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade200,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.deepPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'المرفقات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.pink.shade300 : const Color(0xFFE1BEE7),
                          foregroundColor: isDark ? Colors.black87 : Colors.deepPurple.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'حفظ',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.pink.shade300 : Colors.deepPurple,
                          side: BorderSide(
                            color: isDark ? Colors.pink.shade300 : Colors.deepPurple,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // حالة البلاغ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حالة الطلب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(selectedTicket!.status, isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedTicket!.status,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(selectedTicket!.status, isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'آخر تحديث في',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  _formatDateTime(selectedTicket!.lastUpdate ?? selectedTicket!.createdAt),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ردود المنصة
          if (selectedTicket!.replies.isNotEmpty) ...[
            ...selectedTicket!.replies.where((r) => r.from == 'platform').map((reply) =>
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعليق منصة نوافذ (300 حرف)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reply.message,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // حقل الرد
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _replyController,
              maxLength: 300,
              maxLines: 3,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'رد على التعليق (300 حرف)',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // زر إرسال الرد
          Center(
            child: ElevatedButton(
              onPressed: _sendReply,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.pink.shade300 : const Color(0xFFE1BEE7),
                foregroundColor: isDark ? Colors.black87 : Colors.deepPurple.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              ),
              child: const Text(
                'إرسال',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
