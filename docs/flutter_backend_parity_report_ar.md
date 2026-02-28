# تقرير المطابقة والتوافق (Flutter Mobile ↔ Django Backend)

تاريخ التقرير: 2026-02-25  
آخر تحديث: 2026-02-28

## 1) صورة عامة سريعة
### مكونات المشروع
- **Backend (Django + DRF)**: واجهات REST تحت `/api/*` + صفحات منصة HTML تحت `/dashboard/` + بوابة خدمات إضافية تحت `/portal/extras/`.
- **Flutter Mobile**: تطبيق موبايل رئيسي (routes في `mobile/lib/main.dart`).
- **Flutter Web**: تم إيقافه وحذف ملفاته من المستودع بتاريخ **2026-02-28** تمهيدًا للاستبدال مستقبلاً بصفحات HTML.

### ملاحظة مهمة عن "الويب"
حاليًا عندك ويب تشغيلي واحد داخل هذا المستودع:
1) **Django Web Dashboard**: صفحات HTML للمنصة (إدارية/تشغيلية) تحت `/dashboard/`.
2) **بوابة Extras HTML** تحت `/portal/extras/`.

أما واجهة Flutter Web السابقة فقد تم حذفها بالكامل.

---

## 2) الربط مع الـ API (Base URL + Prefix)
- في Flutter يتم بناء المسارات عبر:
  - `ApiConfig.baseUrl` (مثال افتراضي: Render)
  - `ApiConfig.apiPrefix = '/api'`

أي endpoint في الباكند مثل: `/api/support/teams/` يتم استدعاؤه من Flutter كالتالي:
- `${ApiConfig.apiPrefix}/support/teams/`

---

## 3) CORS (للواجهات الويب HTML الحالية/القادمة)
- الباكند يستخدم `django-cors-headers`.
- في `backend/config/settings/base.py` يوجد `CORS_ALLOW_ALL_ORIGINS` مبني على env (`CORS_ALLOW_ALL`)، وفي `prod.py` يتم جعله `False` مع `CORS_ALLOWED_ORIGINS`.

**النتيجة العملية**:
- Flutter Mobile عادة لا يتأثر بـ CORS.
- أي واجهة HTML/JS على دومين منفصل ستتأثر مباشرة: يجب ضبط `DJANGO_CORS_ALLOWED_ORIGINS` (أو `CORS_ALLOWED_ORIGINS`) لتشمل دومين الواجهة.

---

## 4) مصفوفة مطابقة عالية المستوى حسب الشخصية (Persona)

### أ) العميل (Client)
- Flutter Mobile: موجود (Home/Orders/Profile/Notifications/Chat…)
- Backend API: موجود تحت `/api/marketplace/*`, `/api/messaging/*`, `/api/support/*`, `/api/promo/*`…

**ملاحظات**:
- دعم التذاكر للعميل: `/api/support/tickets/my/`, `/api/support/tickets/create/`.
- طلبات الترويج للعميل: `/api/promo/requests/my/`, `/api/promo/requests/create/`.

### ب) مقدم الخدمة (Provider)
- Flutter Mobile: موجود
- Backend API: موجود تحت `/api/providers/*`, `/api/reviews/*`, `/api/marketplace/*`…

### ج) التشغيل (Operations / Staff)
- Django Dashboard: تغطية واسعة جدًا (Support, Promo, Verification, Subscriptions, Billing, Content, Categories…)

### د) لوحة المنصة (Admin Dashboard)
- Django Dashboard تحت `/dashboard/` يحتوي مسارات كثيرة جدًا (راجع `backend/apps/dashboard/urls.py`).

---

## 5) فجوات مطابقة واضحة (Backlog مرتب)

### فجوة 1: واجهة HTML بديلة للمستخدمين
بعد حذف Flutter Web، إذا كان المطلوب واجهة ويب للمستخدمين (عميل/مزود)، فيلزم تنفيذ واجهة HTML جديدة وربطها بالـ APIs الحالية.

### فجوة 2: Status labels/filters في Promotions
في الباكند statuses للترويج:
- `new`, `in_review`, `quoted`, `pending_payment`, `active`, `rejected`, ...

في الواجهات العميلية السابقة كانت الفلاتر تستخدم مفاهيم مثل `approved/pending/rejected`.
- تم توسيع المطابقة بالمنطق (بدون تغيير مسميات الواجهة) لتشمل `active/in_review/new/...`.
- قد تحتاج لاحقًا توحيد مسميات الفلاتر لتكون 1:1 مع `PromoRequestStatus`.

### فجوة 3: الربط بين واجهة المستخدم الجديدة و Django Dashboard
أي واجهة HTML جديدة يجب أن تحدد بوضوح حدودها مقابل لوحة Django حتى لا يحدث تداخل صلاحيات.

---

## 6) الوضع بعد إزالة Flutter Web

- تم حذف أصول الويب الخاصة بفلتر (`mobile/web`) وملفات البناء المرتبطة بها.
- التطبيق العميلي الفعّال داخل Flutter هو الموبايل فقط.
- واجهات الويب الفعالة في المنصة حاليًا هي HTML ضمن Django.

---

## 7) توصيات تنفيذية سريعة (أعلى عائد بأقل مخاطرة)
1) **تثبيت نطاق الويب الجديد**: تعريف واضح لما سيبقى في Django Dashboard وما سينتقل لواجهة HTML الجديدة.
2) **تثبيت CORS** للواجهة الويب الجديدة في بيئة الإنتاج عبر `DJANGO_CORS_ALLOWED_ORIGINS`.
3) **تقليل التداخل**: أي روابط تخص `/dashboard/` تبقى للأدوار الداخلية فقط.
4) **توحيد statuses/filters** عبر enums أو mapping موحد بين الواجهة والباكند.

---

## 8) ملاحق
### أهم ملفات مرجعية
- Backend routes: `backend/config/urls.py`
- Dashboard routes: `backend/apps/dashboard/urls.py`
- Flutter Mobile routes: `mobile/lib/main.dart`
- Flutter API config: `mobile/lib/config/app_env.dart`
- Flutter HTTP client: `mobile/lib/services/api_client.dart`

