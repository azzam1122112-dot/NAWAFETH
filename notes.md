# أوامر المحاكي (مرتبة وجاهزة للنسخ)

## 1) عرض/تشغيل/إيقاف المحاكي (Android)

```powershell
# عرض المحاكيات
flutter emulators

# تشغيل محاكي (استبدل id)
flutter emulators --launch <emulator_id>

# عرض الأجهزة المتصلة
flutter devices

# إغلاق المحاكي
adb -s emulator-5554 emu kill
```

## 2) تشغيل الباكند محليًا (SQLite)

```powershell
cd C:\Users\manso\nawafeth\backend
.\.venv\Scripts\Activate.ps1
pip install -r requirements\dev.txt
Copy-Item env.example .env -Force
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

## 3) تشغيل الباكند محليًا (PostgreSQL محلي)

```powershell
cd C:\Users\manso\nawafeth\backend
.\.venv\Scripts\Activate.ps1
$env:DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/nawafeth"
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

## 4) تشغيل Flutter على المحاكي (API محلي)

```powershell
cd C:\Users\manso\nawafeth\mobile
flutter pub get
flutter run -d emulator-5554 --dart-define=API_TARGET=local
```

## 5) تشغيل Flutter على المحاكي (API Render)

```powershell
cd C:\Users\manso\nawafeth\mobile
flutter run -d emulator-5554 --dart-define=API_TARGET=render --dart-define=API_RENDER_BASE_URL=https://nawafeth-backend.onrender.com
```

## 6) تشغيل Flutter بعنوان API صريح

```powershell
cd C:\Users\manso\nawafeth\mobile
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://nawafeth-backend.onrender.com
```

## 7) تحديث Android Emulator و SDK Tools (Windows)

```powershell
$SDK="$env:LOCALAPPDATA\Android\Sdk"
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" --update
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" "emulator" "platform-tools"
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" --list | Select-String "system-images;android-"
```

## 8) تثبيت أحدث System Image (مثال)

```powershell
$SDK="$env:LOCALAPPDATA\Android\Sdk"
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-35;google_apis_playstore;x86_64"
```

## 9) نشر آخر نسخة إلى Render (Backend + Render DB)

```powershell
cd C:\Users\manso\nawafeth
git add .
git commit -m "deploy"
git push origin main
```

---

# 📊 مسح شامل: شاشات Flutter والربط بالـ Backend API

> **تاريخ المسح:** 2026-02-28
> **آخر تحديث:** 2026-02-28
> **إجمالي ملفات الشاشات:** 48 ملف dart
> **المتصلة فعلاً بالـ API:** 17 شاشة (+ 7 ملفات بنية تحتية services)
> **غير المتصلة (تحتاج ربط):** 27 شاشة
> **لا تحتاج ربط (ثابتة/أغلفة):** 4 شاشات

---

## ✅ الشاشات المتصلة فعلاً بالـ API (17 شاشة — لا تحتاج عمل)

| # | الملف | الوصف | الـ Service | الـ Endpoint |
|---|-------|-------|-----------|-------------|
| 1 | `lib/screens/login_screen.dart` | تسجيل الدخول بـ OTP | `auth_api_service` | `/api/accounts/otp/send/` |
| 2 | `lib/screens/twofa_screen.dart` | التحقق الثنائي OTP | `auth_api_service` | `/api/accounts/otp/verify/` |
| 3 | `lib/screens/signup_screen.dart` | إكمال التسجيل | `auth_api_service` | `/api/accounts/complete/` |
| 4 | `lib/screens/my_profile_screen.dart` | ملفي الشخصي (نافذتي) | `profile_service` | `/api/accounts/me/` |
| 5 | `lib/screens/provider_dashboard/provider_home_screen.dart` | لوحة تحكم المزود | `profile_service` | `/api/providers/me/profile/` |
| 6 | `lib/screens/interactive_screen.dart` | التفاعلات (متابعين/مفضلة) | `interactive_service` | `/api/providers/{id}/follow/` + `/favorites/` |
| 7 | `lib/screens/my_chats_screen.dart` | قائمة المحادثات | `messaging_service` | `/api/messaging/direct/threads/` |
| 8 | `lib/screens/chat_detail_screen.dart` | تفاصيل المحادثة + الإرسال | `messaging_service` | `/api/messaging/direct/thread/{id}/messages/` + `/send/` |
| 9 | `lib/screens/notifications_screen.dart` | قائمة الإشعارات | `notification_service` | `/api/notifications/` |
| 10 | `lib/screens/notification_settings_screen.dart` | إعدادات الإشعارات | `notification_service` | `/api/notifications/preferences/` |
| 11 | `lib/screens/client_orders_screen.dart` | طلبات العميل | `marketplace_service` | `/api/marketplace/client/requests/` |
| 12 | `lib/screens/client_order_details_screen.dart` | تفاصيل طلب العميل | `marketplace_service` | `/api/marketplace/client/requests/{id}/` |
| 13 | `lib/screens/provider_dashboard/provider_orders_screen.dart` | طلبات المزوّد | `marketplace_service` | `/api/marketplace/provider/requests/` |
| 14 | `lib/screens/provider_dashboard/provider_order_details_screen.dart` | تفاصيل طلب المزوّد | `marketplace_service` | `/api/marketplace/provider/requests/{id}/detail/` |
| 15 | `lib/screens/service_request_form_screen.dart` | نموذج إرسال طلب خدمة | `marketplace_service` | `/api/marketplace/requests/create/` + `/categories/` |
| 16 | `lib/screens/login_settings_screen.dart` | إعدادات الحساب | `profile_service` | `/api/accounts/me/` (GET + PATCH) |
| 17 | `lib/screens/plans_screen.dart` | عرض الباقات والاشتراك | `subscriptions_service` | `/api/subscriptions/plans/` + `/subscribe/` |

---

## 🔴 الشاشات غير المتصلة — مجمّعة حسب الوظيفة

---

### 1️⃣ المراسلات والمحادثات (Messaging) — ✅ مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 1 | `lib/screens/my_chats_screen.dart` | قائمة المحادثات | ✅ متصل | `/api/messaging/direct/threads/` | ✅ تم |
| 2 | `lib/screens/chat_detail_screen.dart` | تفاصيل المحادثة | ✅ متصل | `/api/messaging/direct/thread/{id}/messages/` + `/send/` | ✅ تم |

**Service:** `messaging_service.dart` — threads, messages, send, read, favorite, archive, block, report

---

### 2️⃣ الطلبات — جهة العميل (Client Orders / Marketplace) — ✅ الأساسي مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 3 | `lib/screens/client_orders_screen.dart` | قائمة طلبات العميل | ✅ متصل | `/api/marketplace/client/requests/` | ✅ تم |
| 4 | `lib/screens/client_order_details_screen.dart` | تفاصيل طلب العميل | ✅ متصل | `/api/marketplace/client/requests/{id}/` | ✅ تم |
| 5 | `lib/screens/orders_hub_screen.dart` | مركز الطلبات (غلاف) | ⚪ غلاف | يستخدم `ClientOrdersScreen(embedded: true)` | ⚪ لا يحتاج |
| 6 | `lib/screens/service_request_form_screen.dart` | نموذج إرسال طلب خدمة | ✅ متصل | `/api/marketplace/requests/create/` + `/categories/` | ✅ تم |
| 7 | `lib/screens/search_screen.dart` | طلبات الخدمة التنافسية | ❌ بيانات وهمية | `/api/marketplace/requests/create/` | 🟡 عالي |
| 8 | `lib/screens/request_quote_screen.dart` | طلب عرض سعر | ❌ بيانات وهمية | `/api/marketplace/requests/create/` | 🟡 عالي |
| 9 | `lib/screens/urgent_request_screen.dart` | طلب خدمة عاجلة | ❌ بيانات وهمية | `/api/marketplace/requests/create/` + urgent flag | 🟡 عالي |

**Service:** `marketplace_service.dart` — 20+ endpoint: create, categories, client/provider requests, offers, start, complete, cancel, progress

---

### 3️⃣ الطلبات — جهة مقدم الخدمة (Provider Orders) — ✅ مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 10 | `lib/screens/provider_dashboard/provider_orders_screen.dart` | قائمة طلبات المزوّد | ✅ متصل | `/api/marketplace/provider/requests/` | ✅ تم |
| 11 | `lib/screens/provider_dashboard/provider_order_details_screen.dart` | تفاصيل طلب المزوّد | ✅ متصل | `/api/marketplace/provider/requests/{id}/detail/` | ✅ تم |

**Service:** `marketplace_service.dart` — accept, reject, start, progress update, complete

---

### 4️⃣ البحث وعرض مقدمي الخدمات (Providers / Search)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 12 | `lib/screens/search_provider_screen.dart` | البحث عن مقدم خدمة | ❌ بيانات وهمية | `/api/providers/list/` | 🔴 حرج |
| 13 | `lib/screens/provider_profile_screen.dart` | بروفايل مقدم خدمة (عام) | ❌ بيانات وهمية | `/api/providers/{id}/` + `/services/` + `/portfolio/` | 🔴 حرج |
| 14 | `lib/screens/providers_map_screen.dart` | خريطة مقدمي الخدمات | ❌ بيانات تجريبية | `/api/providers/list/?lat=&lng=` | 🟡 عالي |
| 15 | `lib/screens/service_detail_screen.dart` | تفاصيل الخدمة | ❌ بيانات وهمية | `/api/providers/{id}/services/` | 🟡 عالي |

**Backend جاهز:** `apps/providers` — list, detail, categories, services, portfolio, spotlights, stats, follow/like

---

### 5️⃣ لوحة تحكم المزوّد — تبويبات (Provider Dashboard Tabs)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 16 | `lib/screens/provider_dashboard/profile_tab.dart` | تبويب الملف الشخصي | ❌ بيانات وهمية محلية | `/api/providers/me/profile/` (PATCH) | 🟡 عالي |
| 17 | `lib/screens/provider_dashboard/services_tab.dart` | تبويب الخدمات | ❌ بيانات وهمية | `/api/providers/me/services/` | 🟡 عالي |
| 18 | `lib/screens/provider_dashboard/reviews_tab.dart` | تبويب التقييمات | ❌ بيانات وهمية | `/api/reviews/providers/{id}/reviews/` | 🟡 عالي |
| 19 | `lib/screens/provider_dashboard/promotion_screen.dart` | شاشة الترويج | ❌ ملف فارغ | `/api/promo/requests/create/` | 🟠 متوسط |
| 20 | `lib/screens/provider_dashboard/upgrade_screen.dart` | ترقية الباقة | ❌ ملف فارغ | `/api/subscriptions/plans/` + `/subscribe/` | 🟠 متوسط |
| 21 | `lib/screens/provider_dashboard/verification_screen.dart` | شاشة التوثيق (لوحة المزود) | ❌ ملف فارغ | `/api/verification/requests/create/` | 🟠 متوسط |

**Backend جاهز:** `apps/providers`, `apps/reviews`, `apps/promo`, `apps/subscriptions`, `apps/verification`

---

### 6️⃣ إكمال ملف المزوّد والتسجيل (Registration / Profile Completion)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 22 | `lib/screens/registration/register_service_provider.dart` | تسجيل مقدم خدمة جديد | ❌ لا يرسل للـ API | `/api/providers/register/` | 🔴 حرج |
| 23 | `lib/screens/registration/steps/personal_info_step.dart` | المعلومات الأساسية | ❌ محلي فقط | `/api/providers/register/` (جزء 1) | 🔴 حرج |
| 24 | `lib/screens/registration/steps/service_classification_step.dart` | تصنيف الاختصاص | ❌ محلي فقط | `/api/providers/categories/` + register | 🔴 حرج |
| 25 | `lib/screens/registration/steps/contact_info_step.dart` | بيانات التواصل | ❌ محلي فقط | `/api/providers/register/` (جزء 3) | 🔴 حرج |
| 26 | `lib/screens/provider_dashboard/provider_profile_completion_screen.dart` | إكمال الملف بعد التسجيل | ❌ محلي فقط | `/api/providers/me/profile/` (PATCH) | 🟡 عالي |
| 27 | `lib/screens/registration/steps/service_details_step.dart` | تفاصيل الخدمات | ❌ محلي فقط | `/api/providers/me/services/` (POST) | 🟡 عالي |
| 28 | `lib/screens/registration/steps/additional_details_step.dart` | تفاصيل إضافية | ❌ محلي فقط | `/api/providers/me/profile/` (PATCH) | 🟡 عالي |
| 29 | `lib/screens/registration/steps/language_location_step.dart` | اللغة والموقع | ❌ محلي فقط | `/api/providers/me/profile/` (PATCH) | 🟡 عالي |
| 30 | `lib/screens/registration/steps/content_step.dart` | محتوى المعرض (بورتفوليو) | ❌ محلي فقط | `/api/providers/me/portfolio/` | 🟡 عالي |
| 31 | `lib/screens/registration/steps/seo_step.dart` | إعدادات SEO | ❌ محلي فقط | `/api/providers/me/profile/` (PATCH) | 🟢 منخفض |
| 32 | `lib/screens/registration/steps/map_radius_picker_screen.dart` | اختيار الموقع على الخريطة | ❌ أداة مساعدة | لا يحتاج endpoint مستقل | 🟢 منخفض |

**Backend جاهز:** `apps/providers` — register, me/profile PATCH, me/services, me/portfolio, categories

---

### 7️⃣ الإشعارات (Notifications) — ✅ مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 33 | `lib/screens/notifications_screen.dart` | قائمة الإشعارات | ✅ متصل | `/api/notifications/` | ✅ تم |
| 34 | `lib/screens/notification_settings_screen.dart` | إعدادات الإشعارات | ✅ متصل | `/api/notifications/preferences/` | ✅ تم |

**Service:** `notification_service.dart` — list, unread-count, mark-read, preferences, device-token

---

### 8️⃣ الدعم الفني (Support)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 35 | `lib/screens/contact_screen.dart` | التذاكر / الدعم الفني | ❌ بيانات تجريبية | `/api/support/tickets/create/` + `/tickets/my/` | 🟡 عالي |

**Backend جاهز:** `apps/support` — create, my tickets, detail, comments, attachments

---

### 9️⃣ التوثيق (Verification)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 36 | `lib/screens/verification_screen.dart` | طلب التوثيق (أزرق/أخضر) | ❌ بيانات وهمية | `/api/verification/requests/create/` + `/documents/` | 🟡 عالي |

**Backend جاهز:** `apps/verification` — create, my requests, add document, add requirement attachment

---

### 🔟 الاشتراكات والباقات (Subscriptions / Plans) — ✅ مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 37 | `lib/screens/plans_screen.dart` | عرض الباقات والاشتراك | ✅ متصل | `/api/subscriptions/plans/` + `/subscribe/` | ✅ تم |

**Service:** `subscriptions_service.dart` — plans, my subscriptions, subscribe

---

### 1️⃣1️⃣ الخدمات الإضافية (Extras)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 38 | `lib/screens/additional_services_screen.dart` | الخدمات الإضافية | ❌ بيانات وهمية | `/api/extras/catalog/` + `/buy/{sku}/` | 🟠 متوسط |

**Backend جاهز:** `apps/extras` — catalog, my extras, buy

---

### 1️⃣2️⃣ الصفحة الرئيسية والمحتوى (Home / Content)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 39 | `lib/screens/home_screen.dart` | الصفحة الرئيسية | ❌ widgets محلية | `/api/content/public/` + `/api/promo/banners/home/` + `/api/providers/list/` | 🔴 حرج |

**Backend جاهز:** `apps/content` (public), `apps/promo` (banners), `apps/providers` (list)

---

### 1️⃣3️⃣ الإعدادات والحساب (Settings / Account) — ✅ مكتمل

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint | الأولوية |
|---|-------|--------------|-----------|-------------|---------|
| 40 | `lib/screens/login_settings_screen.dart` | إعدادات الحساب | ✅ متصل | `/api/accounts/me/` (GET + PATCH) | ✅ تم |

**Service:** `profile_service.dart` — fetchMyProfile, updateMyProfile

---

### 1️⃣4️⃣ صفحات ثابتة (Static / Info)

| # | الملف | الوصف بالعربي | API متصل؟ | الـ Endpoint المطلوب | الأولوية |
|---|-------|--------------|-----------|---------------------|---------|
| 41 | `lib/screens/about_screen.dart` | من نحن | ❌ نص ثابت | `/api/content/public/` (اختياري) | 🟢 منخفض |
| 42 | `lib/screens/terms_screen.dart` | الشروط والأحكام | ❌ نص ثابت | `/api/content/public/` (اختياري) | 🟢 منخفض |
| 43 | `lib/screens/onboarding_screen.dart` | شاشة الترحيب | ❌ ثابت | لا يحتاج API | 🟢 منخفض |
| 44 | `lib/screens/add_service_screen.dart` | شاشة "إضافة خدمة" (توجيه) | ❌ واجهة توجيه | لا يحتاج API مستقل | 🟢 منخفض |

---

## 📋 ملفات الـ Services المُنشأة (Flutter)

| الملف | الوصف | أهم الـ Methods |
|-------|-------|----------------|
| `lib/services/api_client.dart` | العميل الأساسي (HTTP + JWT) | `get()`, `post()`, `patch()`, `delete()`, `parseResponse()` (public) |
| `lib/services/auth_service.dart` | إدارة التوكن/الجلسة | `isLoggedIn()`, `getToken()`, `logout()`, `getRoleState()` |
| `lib/services/auth_api_service.dart` | Auth endpoints | `sendOtp()`, `verifyOtp()`, `completeRegistration()` |
| `lib/services/profile_service.dart` | الملف الشخصي | `fetchMyProfile()`, `updateMyProfile()`, `fetchProviderProfile()`, `updateProviderProfile()` |
| `lib/services/interactive_service.dart` | التفاعلات | `fetchFollowing()`, `fetchFollowers()`, `fetchFavorites()` |
| `lib/services/messaging_service.dart` | المراسلات | `fetchThreads()`, `fetchMessages()`, `sendTextMessage()`, `sendAttachment()`, `markRead()`, `toggleFavorite()`, `toggleBlock()` |
| `lib/services/notification_service.dart` | الإشعارات | `fetchNotifications()`, `markRead()`, `markAllRead()`, `fetchPreferences()`, `updatePreferences()` |
| `lib/services/marketplace_service.dart` | السوق/الطلبات | `getCategories()`, `createRequest()`, `getClientRequests()`, `getProviderRequests()`, `acceptRequest()`, `rejectRequest()`, `startRequest()`, `completeRequest()`, `updateProgress()` |
| `lib/services/subscriptions_service.dart` | الاشتراكات | `getPlans()`, `mySubscriptions()`, `subscribe()` |

## 📋 ملفات الـ Models المُنشأة (Flutter)

| الملف | الوصف |
|-------|-------|
| `lib/models/user_profile.dart` | `UserProfile` — بيانات المستخدم الشاملة |
| `lib/models/service_request_model.dart` | `ServiceRequest`, `RequestAttachment`, `StatusLog`, `Offer` |

---

## 📋 خريطة Backend Apps ↔ الـ Endpoints

| Backend App | API Prefix | أهم الـ Endpoints |
|-------------|-----------|-------------------|
| `accounts` | `/api/accounts/` | `otp/send/`, `otp/verify/`, `complete/`, `me/`, `wallet/`, `token/` |
| `providers` | `/api/providers/` | `register/`, `list/`, `me/profile/`, `me/services/`, `me/portfolio/`, `me/spotlights/`, `categories/`, `{id}/`, `{id}/follow/`, `{id}/like/` |
| `marketplace` | `/api/marketplace/` | `requests/create/`, `urgent/accept/`, `client/requests/`, `provider/requests/`, `offers/`, `{id}/start/`, `{id}/complete/`, `{id}/cancel/` |
| `messaging` | `/api/messaging/` | `direct/threads/`, `direct/thread/{id}/messages/`, `direct/thread/{id}/messages/send/`, `thread/{id}/favorite/`, `thread/{id}/block/` |
| `notifications` | `/api/notifications/` | (list), `unread-count/`, `mark-read/{id}/`, `mark-all-read/`, `preferences/`, `device-token/` |
| `reviews` | `/api/reviews/` | `requests/{id}/review/`, `reviews/{id}/provider-reply/`, `providers/{id}/reviews/`, `providers/{id}/rating/` |
| `support` | `/api/support/` | `teams/`, `tickets/create/`, `tickets/my/`, `tickets/{id}/`, `tickets/{id}/comments/` |
| `verification` | `/api/verification/` | `requests/create/`, `requests/my/`, `requests/{id}/documents/` |
| `subscriptions` | `/api/subscriptions/` | `plans/`, `my/`, `subscribe/{plan_id}/` |
| `billing` | `/api/billing/` | `invoices/`, `invoices/my/`, `invoices/{id}/init-payment/` |
| `promo` | `/api/promo/` | `requests/create/`, `requests/my/`, `banners/home/`, `active/` |
| `extras` | `/api/extras/` | `catalog/`, `my/`, `buy/{sku}/` |
| `content` | `/api/content/` | `public/` |
| `features` | `/api/features/` | `my/` |
| `analytics` | `/api/analytics/` | `kpis/`, `revenue/daily/`, `revenue/monthly/` |

---

## 🎯 ملخص الأولويات

| الأولوية | العدد | الشاشات |
|----------|------|---------|
| ✅ **تم الربط** | 17 | Auth (3)، Dashboard (2)، Interactive (1)، Messaging (2)، Notifications (2)، Orders (5)، Settings (1)، Plans (1) |
| 🔴 **حرج** | 5 | الرئيسية، البحث عن مزود، بروفايل المزود، تسجيل المزود (4 خطوات) |
| 🟡 **عالي** | 10 | تبويبات لوحة المزود، إكمال الملف، التوثيق، الدعم الفني، الخريطة، تفاصيل الخدمة، بحث/عرض سعر/عاجل |
| 🟠 **متوسط** | 3 | الترويج، ترقية الباقة، الخدمات الإضافية |
| 🟢 **منخفض** | 5 | من نحن، الشروط، الترحيب، التوجيه، الخريطة المصغرة، SEO |
| ⚪ **لا يحتاج** | 4 | أغلفة: orders_hub, home (layout shell), onboarding, add_service |

---

## 🔑 خطة العمل المقترحة (بالترتيب)

### ✅ ما تم إنجازه

| الجلسة | ما تم ربطه | الـ Services المُنشأة |
|--------|-----------|---------------------|
| 1 | `my_profile_screen` + `provider_home_screen` (Dashboards) | `profile_service.dart` |
| 2 | `interactive_screen` (متابعين/مفضلة) | `interactive_service.dart` |
| 3 | `login_screen` + `twofa_screen` + `signup_screen` (Auth) | `auth_api_service.dart` |
| 4 | `my_chats_screen` + `chat_detail_screen` (Messaging) | `messaging_service.dart` |
| 5 | `notifications_screen` + `notification_settings_screen` | `notification_service.dart` |
| 6 | `client_orders_screen` + `client_order_details_screen` + `provider_orders_screen` + `provider_order_details_screen` + `service_request_form_screen` + `login_settings_screen` + `plans_screen` | `marketplace_service.dart`, `subscriptions_service.dart` |
| 7 | تنظيف `my_profile_screen` (إزالة أقسام المزود من واجهة العميل) | — |

### المرحلة التالية — الأساس (حرج 🔴)
1. `home_screen.dart` — ربط بالبنرات والمزودين والمحتوى
2. `register_service_provider.dart` + 3 steps — ربط بـ `/api/providers/register/`
3. `search_provider_screen.dart` — ربط بـ `/api/providers/list/`
4. `provider_profile_screen.dart` — ربط بـ `/api/providers/{id}/`

### المرحلة 2 — تعزيز (عالي 🟡)
5. `profile_tab.dart` + `services_tab.dart` + `reviews_tab.dart` — تبويبات لوحة المزود
6. `provider_profile_completion_screen.dart` + registration steps (الإكمال)
7. `verification_screen.dart` — ربط بـ verification API
8. `contact_screen.dart` — ربط بـ support API
9. `providers_map_screen.dart` + `service_detail_screen.dart`
10. `search_screen.dart` + `request_quote_screen.dart` + `urgent_request_screen.dart`

### المرحلة 3 — تكميلي (متوسط/منخفض 🟠🟢)
11. `additional_services_screen.dart` — ربط بـ extras API
12. `promotion_screen.dart` + `upgrade_screen.dart` + `verification_screen.dart` (dashboard) — بناء من الصفر
13. الصفحات الثابتة (about, terms) — اختياري من content API
