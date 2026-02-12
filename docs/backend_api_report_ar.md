# تقرير الباكند وواجهات الـ API (Nawafeth)

> هذا التقرير مُستخلص من كود الباكند (Django/DRF/Channels) داخل مجلد `backend/` ويهدف لأن يكون مناسبًا للعرض على:
> 1) العميل (ملخص ما يقدمه النظام)
> 2) الفريق التقني (مرجع API + ملاحظات تشغيل/أمن/نشر)

## 1) ملخص تنفيذي (للعميل)

- المنصّة توفر سوق خدمات: عميل ينشئ طلب خدمة (عادي/تنافسي/عاجل) ومقدّم خدمة يطّلع على الطلبات المتاحة ويقبل/يرسل عروض (للنوع التنافسي) ثم يبدأ التنفيذ ويكمل الطلب.
- تسجيل الدخول يتم عبر OTP للجوال ثم يتم إصدار Tokens (JWT) للتطبيق.
- يوجد نظام مراسلة مرتبط بالطلبات (REST + WebSocket للمحادثة الفورية).
- يوجد نظام فواتير ودفع (حالياً نموذج/Mock لبوابة الدفع) وتُستخدم الفواتير لتوثيق المزوّدين/الإعلانات/الاشتراكات/الإضافات.
- يوجد نظام إشعارات داخلية (قائمة/غير مقروء/وضع كمقروء/تسجيل توكن الجوال).
- يوجد نظام تقييمات للمزوّدين مرتبط بطلب مكتمل.
- يوجد نظام دعم (Tickets) مع دعم Backoffice وتعيين ومتابعة الحالات.

## 2) المكدس التقني (للـ Tech)

- Backend: Django + Django REST Framework
- Auth: JWT عبر `djangorestframework-simplejwt` (Header: `Authorization: Bearer <token>`)
- Realtime: Django Channels + WebSocket
- DB: PostgreSQL عبر `DATABASE_URL` في الإنتاج، وSQLite محلياً عند عدم توفره
- Redis: يُستخدم لـ Channels layer عند توفر `REDIS_URL` (وإلا InMemory محلياً)
- Static: WhiteNoise + `collectstatic`
- CORS: `django-cors-headers`
- Security (prod): SSL redirect + HSTS + secure cookies + CSP (django-csp) + CSRF trusted origins
- Testing: pytest/pytest-django

## 3) التشغيل والنشر (Render)

- Health endpoints:
  - `GET /health/` (alias)
  - `GET /health/live/`
  - `GET /health/ready/` (يتحقق من DB وRedis إن كان مفعّل)
- تشغيل الإنتاج يعتمد ASGI عبر `config.asgi:application` (HTTP + WebSocket).

## 4) المصادقة والأدوار والصلاحيات

### 4.1 JWT
- Access/Refresh من SimpleJWT.
- مدد الـ tokens تُضبط عبر env:
  - `JWT_ACCESS_MIN` (افتراضي 60 دقيقة)
  - `JWT_REFRESH_DAYS` (افتراضي 30 يوم)

### 4.2 Throttling (DRF)
- عام:
  - user: `200/min`
  - anon: `60/min`
- حساس:
  - otp: `5/min` (ScopedRateThrottle في OTP)
  - auth: `15/min` (TokenObtainPair)
  - refresh: `60/min` (TokenRefresh)

### 4.3 حالات دور المستخدم (Role State)
المشروع يستخدم مستوى أدوار داخل `apps.accounts.permissions`:
- visitor: غير مسجل
- phone_only: دخل عبر OTP لكن لم يُكمل التسجيل
- client: عميل مكتمل
- provider: مقدم خدمة
- staff: موظف Django admin

ملاحظة: `ProviderCreateView` يسمح لمستخدم `phone_only` بالتحول لمزوّد دون إلزام `complete_registration`.

### 4.4 Backoffice Access Profile
توجد طبقة صلاحيات للوحات backoffice عبر access_profile (admin/power/user/qa) وallowed modules/dashboards.

## 5) WebSocket (المراسلة الفورية)

### 5.1 المسارات
- `WS /ws/requests/<request_id>/`
- `WS /ws/thread/<thread_id>/`

### 5.2 المصادقة
- الـ WebSocket يعتمد Middleware يقرأ JWT من querystring: `?token=<access>`.

ملاحظة أمنية: وضع التوكن في URL قد يسبب تسريب في logs/proxies. الأفضل دعمه عبر header/subprotocol إن أمكن.

## 6) ملاحظات أمنية وتشغيلية مهمة

- OTP:
  - في التطوير قد يرجع `dev_code` عند `DEBUG=True`.
  - يوجد أوضاع bypass للاختبار/staging (OTP_TEST_MODE / OTP_APP_BYPASS) ويتم تعطيلها قسراً في production settings.
- Webhooks:
  - `WebhookReceiverView` لا يستخدم JWT (متوقع)، لكنه حالياً لا يتحقق من التوقيع؛ يتم فقط تخزين `X-Signature`.
- ملفات/Media على بيئات PaaS قد لا تكون دائمة ما لم يتم توفير storage خارجي.

---

# 7) مرجع الـ API (Endpoints)

> جميع المسارات أدناه تُفهم بالنسبة للـ base root (مثال: `https://<host>/`).
> Prefixes الأساسية موجودة تحت `/api/...` كما في `config/urls.py`.

## 7.1 Accounts — `/api/accounts/`

### OTP + JWT
- `POST /api/accounts/otp/send/`
  - Auth: لا
  - Throttle scope: `otp`
  - Body: `{ "phone": "..." }`
  - Response: `{ "ok": true, "dev_code"?: "1234" }`
  - ملاحظات: cooldown + limits (phone/ip) + audit (best-effort).

- `POST /api/accounts/otp/verify/`
  - Auth: لا
  - Throttle scope: `otp`
  - Body: `{ "phone": "...", "code": "1234" }`
  - Response (نجاح): `{ ok, user_id, role_state, is_new_user, needs_completion, refresh, access }`
  - Response (فشل): رسائل عربية (400/429)

- `POST /api/accounts/token/`
  - Auth: لا
  - Throttle scope: `auth`
  - Body: SimpleJWT username/password
  - Response: SimpleJWT tokens

- `POST /api/accounts/token/refresh/`
  - Auth: لا
  - Throttle scope: `refresh`

### User profile
- `GET /api/accounts/me/`
- `PATCH /api/accounts/me/`
- `PUT /api/accounts/me/`
- `DELETE /api/accounts/me/`
  - Auth: نعم (JWT)
  - Response: payload موسّع (يدعم بيانات مزوّد وعدادات follow/like).

- `POST /api/accounts/complete/`
  - Auth: نعم
  - هدفه: ترقية `phone_only/visitor` إلى `client` بعد إدخال بيانات.

### Wallet
- `GET /api/accounts/wallet/`
- `POST /api/accounts/wallet/`
  - Auth: نعم (على الأقل phone_only)
  - ملاحظة: POST لا يغيّر شيئاً حالياً (نفس استجابة GET).

## 7.2 Providers — `/api/providers/`

### Public
- `GET /api/providers/categories/` (AllowAny)
- `GET /api/providers/list/` (AllowAny)
  - Query: `q`, `city`, `category_id`, `subcategory_id`
- `GET /api/providers/<provider_id>/services/` (AllowAny) — active services
- `GET /api/providers/<provider_id>/portfolio/` (AllowAny)
- `GET /api/providers/<pk>/` (AllowAny)

### Provider self-service
- `POST /api/providers/register/` (IsAtLeastPhoneOnly)
  - ينشئ ProviderProfile ويرقي الدور إلى `provider`.

- `GET /api/providers/me/profile/` + `PATCH/PUT` (IsAtLeastClient)
- `GET /api/providers/me/subcategories/` + `PUT` (IsAtLeastProvider)
- `GET /api/providers/me/services/` + `POST` (IsAtLeastProvider)
- `GET /api/providers/me/services/<pk>/` + `PATCH/PUT/DELETE` (IsAtLeastProvider)

### Social / Favorites
- `POST /api/providers/<provider_id>/follow/` (IsAtLeastPhoneOnly)
- `POST /api/providers/<provider_id>/unfollow/` (IsAtLeastPhoneOnly)
- `POST /api/providers/<provider_id>/like/` (IsAtLeastPhoneOnly)
- `POST /api/providers/<provider_id>/unlike/` (IsAtLeastPhoneOnly)

- `GET /api/providers/me/following/` (IsAtLeastPhoneOnly)
- `GET /api/providers/me/likes/` (IsAtLeastPhoneOnly)
- `GET /api/providers/me/followers/` (IsAtLeastProvider)
- `GET /api/providers/me/likers/` (IsAtLeastProvider)

### Portfolio likes
- `GET /api/providers/me/portfolio/` + `POST` (IsAtLeastProvider)
- `GET /api/providers/me/favorites/` (IsAtLeastPhoneOnly)
- `POST /api/providers/portfolio/<item_id>/like/` (IsAtLeastPhoneOnly)
- `POST /api/providers/portfolio/<item_id>/unlike/` (IsAtLeastPhoneOnly)

## 7.3 Marketplace — `/api/marketplace/`

### Client
- `POST /api/marketplace/requests/create/` (IsAtLeastClient)
  - ينشئ ServiceRequest ويضبط status = `sent`؛ وللعاجل يضبط `expires_at`.

- `GET /api/marketplace/client/requests/` (IsAtLeastClient)
  - Filters: `status`, `type`, `q`

- `GET /api/marketplace/client/requests/<request_id>/` (IsAtLeastClient)

- `POST /api/marketplace/requests/<request_id>/cancel/` (JWT)
  - شرط: مالك الطلب + حالات محددة
  - Body: `{ note?: "..." }`

- عروض الطلب التنافسي:
  - `GET /api/marketplace/requests/<request_id>/offers/` (IsAtLeastClient)
  - `POST /api/marketplace/offers/<offer_id>/accept/` (JWT)

### Provider inbox
- `GET /api/marketplace/provider/urgent/available/` (IsAuthenticated + ProviderProfile)
- `GET /api/marketplace/provider/competitive/available/` (IsAuthenticated + ProviderProfile)
- `GET /api/marketplace/provider/requests/` (IsAuthenticated + ProviderProfile)

- قبول/رفض طلب مُعيّن لمزوّد (غير تنافسي):
  - `POST /api/marketplace/provider/requests/<request_id>/accept/`
  - `POST /api/marketplace/provider/requests/<request_id>/reject/` (Body: `{ note?: "..." }`)

### Competitive offers
- `POST /api/marketplace/requests/<request_id>/offers/create/` (Provider)
  - Body: حسب OfferCreateSerializer

### Urgent accept
- `POST /api/marketplace/requests/urgent/accept/` (Provider)
  - Body: `{ request_id: number }`

### Provider execution lifecycle
- `POST /api/marketplace/requests/<request_id>/start/` (Provider) (Body: `{ note?: "..." }`)
- `POST /api/marketplace/requests/<request_id>/complete/` (Provider) (Body: `{ note?: "..." }`)

## 7.4 Messaging — `/api/messaging/`

- `GET /api/messaging/requests/<request_id>/thread/` (JWT + IsRequestParticipant)
- `POST /api/messaging/requests/<request_id>/thread/` (نفس GET)

- `GET /api/messaging/requests/<request_id>/messages/` (JWT + IsRequestParticipant)
  - Pagination: MessagePagination

- `POST /api/messaging/requests/<request_id>/messages/send/` (JWT + IsRequestParticipant)
  - Body: `{ body: "..." }`
  - Response: `{ ok: true, message_id }`

- `POST /api/messaging/requests/<request_id>/messages/read/` (JWT + IsRequestParticipant)
  - Response: `{ ok, thread_id, marked }`

- Dashboard fallback (Session + CSRF):
  - `POST /api/messaging/thread/<thread_id>/post/`

## 7.5 Notifications — `/api/notifications/`

- `GET /api/notifications/` (IsAtLeastPhoneOnly) — قائمة مع Pagination
- `GET /api/notifications/unread-count/` (IsAtLeastPhoneOnly)
- `POST /api/notifications/mark-read/<notif_id>/` (IsAtLeastPhoneOnly)
- `POST /api/notifications/mark-all-read/` (IsAtLeastPhoneOnly)
- `POST /api/notifications/delete-old/` (IsAtLeastClient) — retention days من settings
- `POST /api/notifications/device-token/` (IsAtLeastClient) — تسجيل FCM token

## 7.6 Reviews — `/api/reviews/`

- `POST /api/reviews/requests/<request_id>/review/` (IsAtLeastClient)
  - ينشئ Review فقط وفق قيود ReviewCreateSerializer (طلب مكتمل/مالك/بدون تكرار).

- `GET /api/reviews/providers/<provider_id>/reviews/` (AllowAny)
- `GET /api/reviews/providers/<provider_id>/rating/` (AllowAny)

## 7.7 Billing — `/api/billing/`

- `POST /api/billing/invoices/` (JWT) — إنشاء فاتورة (InvoiceCreateSerializer)
- `GET /api/billing/invoices/my/` (JWT)
- `GET /api/billing/invoices/<pk>/` (JWT + IsInvoiceOwner)

- `POST /api/billing/invoices/<pk>/init-payment/` (JWT)
  - Body: `{ provider: "...", idempotency_key?: "..." }`
  - Response: PaymentAttemptSerializer (يتضمن checkout_url mock)

- `POST /api/billing/webhooks/<provider>/` (No JWT)
  - Headers: `X-Signature`, `X-Event-Id` (تُخزن حالياً)
  - Body: يتوقع `status`, و`provider_reference` أو `invoice_code`

## 7.8 Verification — `/api/verification/`

### Client
- `POST /api/verification/requests/create/` (IsOwnerOrBackofficeVerify)
- `GET /api/verification/requests/my/`
- `GET /api/verification/requests/<pk>/`
- `POST /api/verification/requests/<pk>/documents/` (Multipart)
  - Fields: `file` + `doc_type` + `title?`
  - يتحقق من الامتداد + حجم الملف وفق max_upload_mb

### Backoffice
- `GET /api/verification/backoffice/requests/`
  - Filters: `status`, `q`
- `PATCH /api/verification/backoffice/documents/<doc_id>/decision/`
  - Body: `{ is_approved: bool, decision_note?: "..." }`
- `POST /api/verification/backoffice/requests/<pk>/finalize/`
  - ينشئ Invoice ويحوّل الحالة إلى `pending_payment` عند اكتمال قبول المستندات.

## 7.9 Promo — `/api/promo/`

### Client
- `POST /api/promo/requests/create/`
- `GET /api/promo/requests/my/`
- `GET /api/promo/requests/<pk>/`
- `POST /api/promo/requests/<pk>/assets/` (Multipart)
  - Fields: `file` + `asset_type?` + `title?`

### Backoffice
- `GET /api/promo/backoffice/requests/`
  - Filters: `status`, `ad_type`, `q`
- `POST /api/promo/backoffice/requests/<pk>/quote/`
  - Body: `{ quote_note?: "..." }`
  - ينشئ Invoice + يحوّل إلى `pending_payment`
- `POST /api/promo/backoffice/requests/<pk>/reject/`
  - Body: `{ reject_reason: "..." }`

## 7.10 Subscriptions — `/api/subscriptions/`

- `GET /api/subscriptions/plans/` (JWT)
- `GET /api/subscriptions/my/` (JWT)
- `POST /api/subscriptions/subscribe/<plan_id>/` (JWT)
  - ينشئ Subscription + Invoice (pending)

ملاحظة: يتم تحديث حالة الاشتراك بشكل best-effort عبر middleware على كل request.

## 7.11 Extras — `/api/extras/`

- `GET /api/extras/catalog/` (JWT)
- `GET /api/extras/my/` (JWT)
- `POST /api/extras/buy/<sku>/` (JWT)

## 7.12 Features — `/api/features/`

- `GET /api/features/my/` (JWT)
  - Response يحتوي boolean flags لبعض الميزات + `max_upload_mb`.

## 7.13 Analytics — `/api/analytics/` (Backoffice)

- `GET /api/analytics/kpis/`
  - Query: `start=YYYY-MM-DD`, `end=YYYY-MM-DD`

- `GET /api/analytics/revenue/daily/`
- `GET /api/analytics/revenue/monthly/`
- `GET /api/analytics/requests/breakdown/`
- `GET /api/analytics/export/paid-invoices.csv`

صلاحية الوصول: `IsBackofficeAnalytics` (يعتمد access_profile وmodules).

---

# 8) Dashboard (HTML) — `/dashboard/`

هذه ليست API JSON لكنها مهمة لعرض داخلي/إداري:
- `GET /dashboard/` + صفحات إدارة الطلبات/المزوّدين/الخدمات/التصنيفات.
- Actions عبر POST لتغيير حالة الطلب (accept/send/start/complete/cancel) وأيضاً تفعيل/إيقاف categories/subcategories/services.

---

# 9) توصيات مختصرة (للفريق)

- إضافة تحقق حقيقي لتوقيع webhooks قبل اعتماد `status=paid`.
- التفكير بدعم مصادقة WS بدون وضع التوكن في URL.
- توثيق/فصل بيئات dev/staging/prod بوضوح (خصوصاً OTP bypass).
- مراقبة أثر `SubscriptionRefreshMiddleware` على الأداء (DB hit لكل request لمستخدم لديه اشتراك).
