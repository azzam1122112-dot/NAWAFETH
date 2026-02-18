import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../services/billing_api.dart';
import '../services/payment_checkout.dart';
import '../services/verification_api.dart';
import '../utils/auth_guard.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final PageController _pageController = PageController();
  final VerificationApi _verificationApi = VerificationApi();
  final BillingApi _billingApi = BillingApi();
  int _currentStep = 0;
  bool _submitting = false;

  // الحالة
  String? selectedType; // "blue" أو "green"
  String? blueOption; // "person" / "company" / "other"
  final List<String> greenOptions = [];
  final List<File> uploadedFiles = [];

  // المدخلات
  final _formKeyBlue = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _crDateCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String _selectedPaymentMethod = "apple"; // apple / card

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await checkFullClient(context);
      if (!ok && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _idCtrl.dispose();
    _dobCtrl.dispose();
    _crCtrl.dispose();
    _crDateCtrl.dispose();
    super.dispose();
  }

  // رفع ملف (صورة مستند)
  Future<void> _pickFile() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => uploadedFiles.add(File(picked.path)));
    }
  }

  // اختيار تاريخ من تقويم وحفظه بصيغة YYYY-MM-DD
  Future<void> _pickDateForController(
    TextEditingController controller, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime(now.year - 25),
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.deepPurple,
              ),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        controller.text = "$y-$m-$d";
      });
    }
  }

  // تحقق من صحة المعطيات قبل الانتقال
  bool _canGoNext() {
    if (_currentStep == 0) {
      return selectedType != null;
    }
    if (_currentStep == 1) {
      if (selectedType == "blue") {
        if (blueOption == null) return false;
        if (blueOption == "person" || blueOption == "company") {
          return _formKeyBlue.currentState?.validate() == true;
        }
        if (blueOption == "other") {
          return uploadedFiles.isNotEmpty;
        }
      } else if (selectedType == "green") {
        return greenOptions.isNotEmpty && uploadedFiles.isNotEmpty;
      }
    }
    return true;
  }

  Future<void> _nextStep() async {
    // تحقق حقول الشارة الزرقاء قبل الانتقال
    if (_currentStep == 1 && selectedType == "blue") {
      _formKeyBlue.currentState?.save();
      if (!_canGoNext()) return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _submitVerificationRequest();
    }
  }

  Future<void> _submitVerificationRequest() async {
    if (_submitting || selectedType == null) return;

    final ok = await checkFullClient(context);
    if (!ok) return;

    setState(() => _submitting = true);
    try {
      final req = await _verificationApi.createRequest(badgeType: selectedType!);
      final requestId = _asInt(req['id']);

      if (requestId == null) {
        throw Exception('verification_request_missing_id');
      }

      final docType = _resolveDocType();
      for (var i = 0; i < uploadedFiles.length; i++) {
        final f = uploadedFiles[i];
        await _verificationApi.addDocument(
          requestId: requestId,
          filePath: f.path,
          docType: docType,
          title: 'document_${i + 1}',
        );
      }

      var paymentInitialized = false;

      // في حال أنشأ الباكند فاتورة مباشرة نبدأ تهيئة الدفع، وإلا ننتظر مراجعة فريق التوثيق.
      final detail = await _verificationApi.getRequestDetail(requestId);
      final invoiceId = _asInt(detail['invoice']);
      if (invoiceId != null) {
        if (!mounted) return;
        paymentInitialized = await PaymentCheckout.initAndOpen(
          context: context,
          billingApi: _billingApi,
          invoiceId: invoiceId,
          idempotencyKey: 'verification-$requestId-${DateTime.now().millisecondsSinceEpoch}',
          successMessage: 'تم إنشاء طلب التوثيق وفتح صفحة الدفع.',
        );
      }

      if (!mounted) return;
      _showSuccess(paymentInitialized: paymentInitialized);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractDioMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال طلب التوثيق حالياً.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _resolveDocType() {
    if (selectedType == 'blue') {
      if (blueOption == 'person') return 'id';
      if (blueOption == 'company') return 'cr';
      return 'other';
    }
    return greenOptions.contains('التراخيص المهنية') ? 'license' : 'other';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _extractDioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      for (final v in data.values) {
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty && v.first is String) {
          final first = (v.first as String).trim();
          if (first.isNotEmpty) return first;
        }
      }
    }
    return 'تعذر إرسال طلب التوثيق حالياً.';
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showSuccess({required bool paymentInitialized}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "تم إرسال طلب التوثيق ✅",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    paymentInitialized
                        ? "تم إرسال الطلب وتهيئة الدفع بنجاح."
                        : "تم إرسال الطلب بنجاح. ستصلك حالة المراجعة ثم الفاتورة عند الاعتماد.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Cairo",
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: const Text(
                        "حسناً",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _amountLabel() =>
      selectedType == "blue" ? "100 ر.س/سنة" : "150 ر.س/سنة";
  int _amount() => selectedType == "blue" ? 100 : 150;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "طلب التوثيق",
          style: TextStyle(
            fontFamily: "Cairo",
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            _ProgressSteps(current: _currentStep),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _step1ChooseBadge(),
                      _step2Details(),
                      _step3Checkout(),
                    ],
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // شريط الأزرار في الأسفل
  Widget _bottomBar() {
    final canNext = _canGoNext();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _submitting ? null : _prevStep,
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text("السابق"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepPurple,
                side: BorderSide(color: AppColors.deepPurple),
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (canNext && !_submitting) ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                disabledBackgroundColor: AppColors.deepPurple.withOpacity(0.25),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_submitting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    Text(
                      _currentStep == 2 ? "تأكيد الدفع" : "التالي",
                      style: const TextStyle(
                        fontFamily: "Cairo",
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _currentStep == 2
                          ? Icons.check_circle_outline
                          : Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // الخطوة 1 — اختيار نوع الشارة
  Widget _step1ChooseBadge() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "اختر نوع التوثيق المناسب لك",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "يمكنك توثيق هويتك أو اعتمادك المهني للحصول على ثقة أكبر لدى العملاء.",
            style: TextStyle(
              fontFamily: "Cairo",
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _badgeCard(
            type: "blue",
            title: "التوثيق بالشارة الزرقاء",
            subtitle: "إثبات الهوية الشخصية أو السجل التجاري كمنشأة.",
            price: 100,
            color: Colors.blue,
            highlightLabel: "هوية / سجل تجاري",
            selected: selectedType == "blue",
            onTap: () => setState(() => selectedType = "blue"),
          ),
          const SizedBox(height: 12),
          _badgeCard(
            type: "green",
            title: "التوثيق بالشارة الخضراء",
            subtitle: "توثيق اعتمادك المهني وشهاداتك وخبراتك العملية.",
            price: 150,
            color: Colors.green,
            highlightLabel: "اعتمادات مهنية",
            selected: selectedType == "green",
            onTap: () => setState(() => selectedType = "green"),
          ),
          const SizedBox(height: 8),
          if (selectedType != null)
            _infoHint(
              text:
                  selectedType == "blue"
                      ? "اختر ما إذا كان التوثيق كفرد أو كيان تجاري أو أوراق رسمية، ثم أكمل البيانات المطلوبة."
                      : "اختر نوع الاعتمادات التي ترغب في توثيقها، ثم أرفق المستندات الداعمة.",
            ),
        ],
      ),
    );
  }

  // الخطوة 2 — تفاصيل حسب نوع الشارة
  Widget _step2Details() {
    if (selectedType == null) {
      return const Center(
        child: Text(
          "يرجى اختيار نوع الشارة أولاً من الخطوة السابقة.",
          style: TextStyle(fontFamily: "Cairo", color: Colors.black54),
        ),
      );
    }

    if (selectedType == "blue") return _blueForm();
    return _greenForm();
  }

  // نموذج الشارة الزرقاء — الخيارات تحت بعض (فرد / كيان تجاري / أوراق رسمية)
  Widget _blueForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "اختر نوع التوثيق بالشارة الزرقاء",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          _optionChoiceCard(
            value: "person",
            groupValue: blueOption,
            title: "فرد",
            subtitle: "توثيق هوية شخصية لمستخدم واحد.",
            icon: Icons.person,
            onTap: () => setState(() => blueOption = "person"),
          ),
          const SizedBox(height: 10),
          _optionChoiceCard(
            value: "company",
            groupValue: blueOption,
            title: "كيان تجاري",
            subtitle: "شركة أو مؤسسة بسجل تجاري موثق.",
            icon: Icons.apartment,
            onTap: () => setState(() => blueOption = "company"),
          ),
          const SizedBox(height: 10),
          _optionChoiceCard(
            value: "other",
            groupValue: blueOption,
            title: "أوراق رسمية",
            subtitle: "خطابات، عقود، أو مستندات رسمية أخرى.",
            icon: Icons.description_outlined,
            onTap: () => setState(() => blueOption = "other"),
          ),
          const SizedBox(height: 16),
          if (blueOption == "person" || blueOption == "company")
            Form(
              key: _formKeyBlue,
              child: Column(
                children: [
                  if (blueOption == "person") ...[
                    _inputField(
                      controller: _idCtrl,
                      label: "رقم الهوية / الإقامة",
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator:
                          (v) =>
                              (v == null || v.trim().length < 8)
                                  ? "يرجى إدخال رقم هوية صالح"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap:
                          () => _pickDateForController(
                            _dobCtrl,
                            firstDate: DateTime(1950),
                            lastDate: DateTime(DateTime.now().year - 10),
                          ),
                      child: AbsorbPointer(
                        child: _inputField(
                          controller: _dobCtrl,
                          label: "تاريخ الميلاد (YYYY-MM-DD)",
                          icon: Icons.calendar_today_outlined,
                          hint: "اختر من التقويم",
                          keyboardType: TextInputType.datetime,
                          validator:
                              (v) =>
                                  (v == null ||
                                          !RegExp(
                                            r'^\d{4}-\d{2}-\d{2}$',
                                          ).hasMatch(v))
                                      ? "صيغة التاريخ غير صحيحة"
                                      : null,
                        ),
                      ),
                    ),
                  ],
                  if (blueOption == "company") ...[
                    _inputField(
                      controller: _crCtrl,
                      label: "رقم السجل التجاري",
                      icon: Icons.business_center_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator:
                          (v) =>
                              (v == null || v.trim().length < 5)
                                  ? "يرجى إدخال رقم سجل صالح"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap:
                          () => _pickDateForController(
                            _crDateCtrl,
                            firstDate: DateTime(1970),
                            lastDate: DateTime.now(),
                          ),
                      child: AbsorbPointer(
                        child: _inputField(
                          controller: _crDateCtrl,
                          label: "تاريخ السجل (YYYY-MM-DD)",
                          icon: Icons.date_range_outlined,
                          hint: "اختر من التقويم",
                          keyboardType: TextInputType.datetime,
                          validator:
                              (v) =>
                                  (v == null ||
                                          !RegExp(
                                            r'^\d{4}-\d{2}-\d{2}$',
                                          ).hasMatch(v))
                                      ? "صيغة التاريخ غير صحيحة"
                                      : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (blueOption == "other") ...[
            const SizedBox(height: 8),
            _filesSectionHeader(),
            const SizedBox(height: 6),
            _uploadBox(),
            const SizedBox(height: 6),
            _filesChips(),
          ],
        ],
      ),
    );
  }

  // كرت اختيار نوع التوثيق في الخطوة الثانية (تحت بعض)
  Widget _optionChoiceCard({
    required String value,
    required String? groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool selected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.deepPurple.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.deepPurple : Colors.grey.shade300,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    selected
                        ? AppColors.deepPurple
                        : AppColors.deepPurple.withOpacity(0.08),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.deepPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: selected ? AppColors.deepPurple : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.deepPurple : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? AppColors.deepPurple : Colors.white,
              ),
              child:
                  selected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  // نموذج الشارة الخضراء
  Widget _greenForm() {
    final options = [
      "توثيق الاعتماد المهني",
      "توثيق الرخص التنظيمية",
      "توثيق الخبرات العملية",
      "توثيق الدرجة العلمية والأكاديمية",
      "توثيق الشهادات الاحترافية",
      "توثيق كفو",
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "اختر العناصر التي ترغب في توثيقها",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                options.map((opt) {
                  final selected = greenOptions.contains(opt);
                  return FilterChip(
                    label: Text(
                      opt,
                      style: const TextStyle(fontFamily: "Cairo"),
                    ),
                    selected: selected,
                    selectedColor: AppColors.deepPurple.withOpacity(0.12),
                    checkmarkColor: AppColors.deepPurple,
                    side: BorderSide(
                      color:
                          selected
                              ? AppColors.deepPurple
                              : Colors.grey.shade300,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          greenOptions.add(opt);
                        } else {
                          greenOptions.remove(opt);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),
          _filesSectionHeader(),
          const SizedBox(height: 6),
          _uploadBox(),
          const SizedBox(height: 6),
          _filesChips(),
          const SizedBox(height: 8),
          _infoHint(
            text:
                "أرفق صور الشهادات أو التراخيص أو المستندات الداعمة لاعتماداتك.",
          ),
        ],
      ),
    );
  }

  // الخطوة 3 — مراجعة الطلب والدفع
  Widget _step3Checkout() {
    final amount = _amount();
    final isBlue = selectedType == "blue";

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "مراجعة الطلب",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "تحقق من تفاصيل طلب التوثيق قبل إتمام عملية الدفع.",
            style: TextStyle(fontFamily: "Cairo", color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors:
                                isBlue
                                    ? [
                                      Colors.blue.shade400,
                                      Colors.blue.shade700,
                                    ]
                                    : [
                                      Colors.green.shade400,
                                      Colors.green.shade700,
                                    ],
                          ),
                        ),
                        padding: const EdgeInsets.all(9),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isBlue
                              ? "التوثيق بالشارة الزرقاء"
                              : "التوثيق بالشارة الخضراء",
                          style: const TextStyle(
                            fontFamily: "Cairo",
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        "$amount ر.س",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  _kvRow("نوع الشارة", isBlue ? "زرقاء" : "خضراء"),
                  const SizedBox(height: 6),
                  if (isBlue && blueOption != null)
                    _kvRow(
                      "نوع التوثيق",
                      blueOption == "person"
                          ? "فرد"
                          : blueOption == "company"
                          ? "كيان تجاري"
                          : "أوراق رسمية",
                    ),
                  if (!isBlue)
                    _kvRow(
                      "عناصر مختارة",
                      greenOptions.isEmpty
                          ? "-"
                          : greenOptions.length.toString(),
                    ),
                  const SizedBox(height: 6),
                  _kvRow("عدد المرفقات", uploadedFiles.length.toString()),
                  const SizedBox(height: 12),
                  if (!isBlue && greenOptions.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "تفاصيل العناصر:",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            greenOptions
                                .map(
                                  (e) => Chip(
                                    label: Text(
                                      e,
                                      style: const TextStyle(
                                        fontFamily: "Cairo",
                                        fontSize: 11,
                                      ),
                                    ),
                                    backgroundColor: AppColors.deepPurple
                                        .withOpacity(0.04),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.deepPurple.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "تفاصيل طلبك سيتم تدقيقها من فريق التوثيق قبل اعتماد الشارة.",
                      style: TextStyle(
                        fontFamily: "Cairo",
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            "طريقة الدفع",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 3,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: "apple",
                  groupValue: _selectedPaymentMethod,
                  activeColor: Colors.black,
                  onChanged: (v) {
                    setState(() => _selectedPaymentMethod = v ?? "apple");
                  },
                  title: Row(
                    children: const [
                      Icon(Icons.phone_iphone, color: Colors.black),
                      SizedBox(width: 8),
                      Text("Apple Pay", style: TextStyle(fontFamily: "Cairo")),
                    ],
                  ),
                ),
                const Divider(height: 0),
                RadioListTile<String>(
                  value: "card",
                  groupValue: _selectedPaymentMethod,
                  activeColor: AppColors.deepPurple,
                  onChanged: (v) {
                    setState(() => _selectedPaymentMethod = v ?? "card");
                  },
                  title: Row(
                    children: const [
                      Icon(
                        Icons.credit_card_outlined,
                        color: Colors.deepPurple,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "بطاقة مدى / فيزا",
                        style: TextStyle(fontFamily: "Cairo"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_selectedPaymentMethod == "apple") ...[
            ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.phone_iphone),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                "يتم التفعيل بعد إنشاء الفاتورة",
                style: TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.credit_card_outlined),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                "يتم التفعيل بعد إنشاء الفاتورة",
                style: TextStyle(fontFamily: "Cairo", fontSize: 15),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              "المبلغ الإجمالي: ${_amount()} ر.س",
              style: const TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _amountLabel(),
              style: const TextStyle(
                fontFamily: "Cairo",
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // بطاقة اختيار الشارة (اسم + سعر في سطر، وصف تحت، بدون تداخل)
  Widget _badgeCard({
    required String type,
    required String title,
    required String subtitle,
    required int price,
    required MaterialColor color,
    required String highlightLabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? LinearGradient(
                    colors: [color.withOpacity(0.10), color.withOpacity(0.02)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                  : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.55) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.08 : 0.03),
              blurRadius: selected ? 18 : 10,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.verified, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // سطر العنوان + السعر
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Cairo",
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                type == "blue"
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$price ر.س/سنة",
                        style: const TextStyle(
                          fontFamily: "Cairo",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      height: 1.4,
                      fontFamily: "Cairo",
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      highlightLabel,
                      style: TextStyle(
                        fontFamily: "Cairo",
                        fontSize: 10.5,
                        color: color.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عنصر إدخال موحد
  Widget _inputField({
    required String label,
    required IconData icon,
    TextEditingController? controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.deepPurple),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.deepPurple, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      style: const TextStyle(fontFamily: "Cairo"),
    );
  }

  Widget _filesSectionHeader() {
    return Row(
      children: const [
        Icon(Icons.cloud_upload_outlined, color: Colors.deepPurple),
        SizedBox(width: 8),
        Text(
          "المرفقات",
          style: TextStyle(fontFamily: "Cairo", fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // صندوق الرفع
  Widget _uploadBox() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        height: 122,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.6),
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.drive_folder_upload,
                size: 40,
                color: Colors.deepPurple,
              ),
              SizedBox(height: 6),
              Text(
                "اضغط هنا لرفع الملفات",
                style: TextStyle(
                  fontFamily: "Cairo",
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "صور الهويات، السجلات، الشهادات...",
                style: TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 11,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عرض المرفقات Chips
  Widget _filesChips() {
    if (uploadedFiles.isEmpty) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          "لم تُرفق ملفات بعد.",
          style: TextStyle(fontFamily: "Cairo", color: Colors.grey.shade600),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < uploadedFiles.length; i++)
          Chip(
            label: Text(
              "ملف ${i + 1}",
              style: const TextStyle(fontFamily: "Cairo"),
            ),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => setState(() => uploadedFiles.removeAt(i)),
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }

  // صف مفتاح / قيمة
  Widget _kvRow(String k, String v) {
    return Row(
      children: [
        Text(
          k,
          style: const TextStyle(fontFamily: "Cairo", color: Colors.black54),
        ),
        const Spacer(),
        Text(
          v,
          style: const TextStyle(
            fontFamily: "Cairo",
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // تلميح معلوماتي
  Widget _infoHint({required String text}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.deepPurple.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.deepPurple, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مؤشّر التقدّم العلوي (3 خطوات) بتصميم حديث
class _ProgressSteps extends StatelessWidget {
  final int current;
  const _ProgressSteps({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = ["اختيار الشارة", "التفاصيل", "الدفع"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= current;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          isActive ? AppColors.deepPurple : Colors.grey[300],
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Cairo",
                        ),
                      ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  isActive
                                      ? [
                                        AppColors.deepPurple,
                                        AppColors.deepPurple.withOpacity(0.4),
                                      ]
                                      : [
                                        Colors.grey.shade300,
                                        Colors.grey.shade300,
                                      ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 11,
                    color:
                        isActive ? AppColors.deepPurple : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
