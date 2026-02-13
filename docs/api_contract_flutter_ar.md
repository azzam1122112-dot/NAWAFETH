# API Contract تفصيلي للوحدات الناقصة (Execution Ready)

> Base URL: `https://<host>`
> 
> Auth: `Authorization: Bearer <access>` لمعظم endpoints.

## 1) Billing - `/api/billing/`

### 1.1 إنشاء فاتورة
- Method/URL: `POST /api/billing/invoices/`
- Auth: مطلوب (JWT)
- Request JSON:
```json
{
  "title": "فاتورة اشتراك",
  "description": "اشتراك باقة Pro",
  "currency": "SAR",
  "subtotal": "199.00",
  "vat_percent": "15.00",
  "reference_type": "subscription",
  "reference_id": "123"
}
```
- Success `201`:
```json
{
  "id": 101,
  "code": "IV000101",
  "title": "فاتورة اشتراك",
  "description": "اشتراك باقة Pro",
  "currency": "SAR",
  "subtotal": "199.00",
  "vat_percent": "15.00",
  "vat_amount": "29.85",
  "total": "228.85",
  "status": "pending",
  "reference_type": "subscription",
  "reference_id": "123",
  "paid_at": null,
  "created_at": "2026-02-13T10:00:00Z",
  "updated_at": "2026-02-13T10:00:00Z"
}
```
- Errors:
  - `400`: `subtotal <= 0`.
  - `401`: بدون/توكن غير صالح.

### 1.2 فواتيري
- Method/URL: `GET /api/billing/invoices/my/`
- Auth: مطلوب
- Success `200`:
```json
[
  {
    "id": 101,
    "code": "IV000101",
    "title": "فاتورة اشتراك",
    "status": "pending",
    "total": "228.85"
  }
]
```
- Errors: `401`.

### 1.3 تفاصيل فاتورة
- Method/URL: `GET /api/billing/invoices/{pk}/`
- Auth: مطلوب
- Success `200`: نفس `InvoiceDetailSerializer`.
- Errors:
  - `401`: غير موثّق.
  - `403`: ليس مالك الفاتورة.
  - `404`: غير موجود.

### 1.4 بدء الدفع
- Method/URL: `POST /api/billing/invoices/{pk}/init-payment/`
- Auth: مطلوب
- Request JSON:
```json
{
  "provider": "mock",
  "idempotency_key": "sub-101-attempt-1"
}
```
- Success `200`:
```json
{
  "id": "2e451f08-9f6f-4a63-a6e9-e412f8a07dfe",
  "provider": "mock",
  "status": "redirected",
  "amount": "228.85",
  "currency": "SAR",
  "checkout_url": "https://example-pay.local/checkout/mock/2e451f08-...",
  "provider_reference": "mock_ref_1a2b3c4d5e6f",
  "created_at": "2026-02-13T10:02:00Z"
}
```
- Errors:
  - `400`: الفاتورة مدفوعة أو provider غير صالح.
  - `401`: غير موثّق.
  - `403`: ليس مالك الفاتورة.

### 1.5 Webhook
- Method/URL: `POST /api/billing/webhooks/{provider}/`
- Auth: لا (Webhook)
- Headers: `X-Signature`, `X-Event-Id` (اختياريان حاليًا)
- Request JSON (مثال paid):
```json
{
  "status": "paid",
  "provider_reference": "mock_ref_1a2b3c4d5e6f"
}
```
- Success `200`:
```json
{
  "ok": true,
  "invoice": "IV000101",
  "status": "paid"
}
```
- Success `200` (attempt not found):
```json
{
  "ok": false,
  "detail": "attempt not found"
}
```
- Errors: لا توجد أكواد 4xx حاليًا (يرجع 200 دائمًا بمعالجة inside-service).

---

## 2) Subscriptions - `/api/subscriptions/`

### 2.1 الخطط
- Method/URL: `GET /api/subscriptions/plans/`
- Auth: مطلوب
- Success `200`:
```json
[
  {
    "id": 1,
    "code": "PRO",
    "title": "Pro",
    "description": "...",
    "period": "month",
    "price": "199.00",
    "features": ["promo_ads", "verify_blue"],
    "is_active": true
  }
]
```
- Errors: `401`.

### 2.2 اشتراكاتي
- Method/URL: `GET /api/subscriptions/my/`
- Auth: مطلوب
- Success `200`:
```json
[
  {
    "id": 77,
    "plan": { "id": 1, "code": "PRO", "title": "Pro", "period": "month", "price": "199.00", "features": ["promo_ads"], "is_active": true },
    "status": "pending_payment",
    "start_at": null,
    "end_at": null,
    "grace_end_at": null,
    "auto_renew": true,
    "invoice": 101,
    "created_at": "2026-02-13T10:05:00Z"
  }
]
```
- Errors: `401`.

### 2.3 الاشتراك بخطة
- Method/URL: `POST /api/subscriptions/subscribe/{plan_id}/`
- Auth: مطلوب
- Request JSON: `{}`
- Success `201`: `SubscriptionSerializer` (مع `invoice` منشأة تلقائيًا).
- Errors:
  - `401`: غير موثّق.
  - `404`: plan غير موجود/غير active.

---

## 3) Verification - `/api/verification/`

### 3.1 إنشاء طلب توثيق
- Method/URL: `POST /api/verification/requests/create/`
- Auth: مطلوب
- Request JSON:
```json
{ "badge_type": "blue" }
```
- Success `201`:
```json
{ "id": 12, "code": "AD000012", "badge_type": "blue" }
```
- Errors:
  - `400`: نوع شارة غير صالح / ميزة غير متاحة حسب الباقة / طلب قائم لنفس الشارة.
  - `401`: غير موثّق.

### 3.2 طلباتي
- Method/URL: `GET /api/verification/requests/my/`
- Auth: مطلوب
- Success `200`: Array من `VerificationRequestDetailSerializer`.
- Errors: `401`.

### 3.3 تفاصيل طلب
- Method/URL: `GET /api/verification/requests/{pk}/`
- Auth: مطلوب
- Success `200`: كائن الطلب + documents.
- Errors:
  - `401`: غير موثّق.
  - `403`: ليس owner ولا backoffice مخوّل.
  - `404`: غير موجود.

### 3.4 رفع مستند
- Method/URL: `POST /api/verification/requests/{pk}/documents/`
- Auth: مطلوب
- Content-Type: `multipart/form-data`
- Body fields:
  - `file` (required)
  - `doc_type` (required: `id|cr|iban|license|other`)
  - `title` (optional)
- Success `201`:
```json
{
  "id": 55,
  "doc_type": "id",
  "title": "هوية",
  "file": "/media/verification/docs/...",
  "is_approved": null,
  "decision_note": "",
  "decided_by": null,
  "decided_at": null,
  "uploaded_by": 7,
  "uploaded_at": "2026-02-13T10:10:00Z"
}
```
- Errors:
  - `400`: مرحلة غير مسموحة / file أو doc_type مفقود / امتداد أو حجم غير صالح.
  - `401`: غير موثّق.
  - `403`: ليس owner ولا backoffice مخوّل.

### 3.5 Backoffice List
- Method/URL: `GET /api/verification/backoffice/requests/?status=&q=`
- Auth: مطلوب + صلاحية backoffice verify.
- Success `200`: Array تفاصيل الطلبات.
- Errors:
  - `401`: غير موثّق.
  - `403`: بدون صلاحية verify.

### 3.6 قرار مستند
- Method/URL: `PATCH /api/verification/backoffice/documents/{doc_id}/decision/`
- Auth: backoffice verify
- Request JSON:
```json
{ "is_approved": true, "decision_note": "مقبول" }
```
- Success `200`:
```json
{ "ok": true }
```
- Errors: `400/401/403/404`.

### 3.7 Finalize + Create Invoice
- Method/URL: `POST /api/verification/backoffice/requests/{pk}/finalize/`
- Auth: backoffice verify
- Request JSON: `{}`
- Success `200`: `VerificationRequestDetailSerializer` (عادة status -> `pending_payment` + `invoice`).
- Errors:
  - `400`: لا مستندات / مستندات undecided / مرحلة غير صالحة.
  - `401/403/404`.

---

## 4) Promo - `/api/promo/`

### 4.1 إنشاء طلب ترويج
- Method/URL: `POST /api/promo/requests/create/`
- Auth: مطلوب
- Request JSON:
```json
{
  "title": "حملة بروفايل",
  "ad_type": "boost_profile",
  "start_at": "2026-03-01T10:00:00Z",
  "end_at": "2026-03-08T10:00:00Z",
  "frequency": "30s",
  "position": "normal",
  "target_category": "تصميم",
  "target_city": "الرياض",
  "redirect_url": "https://example.com"
}
```
- Success `201`: `PromoRequestCreateSerializer`.
- Errors:
  - `400`: promo_ads غير متاحة/تواريخ غير صالحة/قيم enum غير صالحة.
  - `401`.

### 4.2 طلباتي
- Method/URL: `GET /api/promo/requests/my/`
- Auth: مطلوب
- Success `200`: Array `PromoRequestDetailSerializer`.
- Errors: `401`.

### 4.3 تفاصيل طلب
- Method/URL: `GET /api/promo/requests/{pk}/`
- Auth: مطلوب
- Success `200`: كائن تفصيلي.
- Errors: `401/403/404`.

### 4.4 رفع Asset
- Method/URL: `POST /api/promo/requests/{pk}/assets/`
- Auth: مطلوب
- Content-Type: `multipart/form-data`
- Fields:
  - `file` (required)
  - `asset_type` (optional default `image`)
  - `title` (optional)
- Success `201`: `PromoAssetSerializer`.
- Errors:
  - `400`: مرحلة غير مسموحة / file مفقود / ملف غير صالح.
  - `401/403/404`.

### 4.5 Backoffice List
- Method/URL: `GET /api/promo/backoffice/requests/?status=&ad_type=&q=`
- Auth: backoffice promo
- Success `200`: Array تفاصيل.
- Errors: `401/403`.

### 4.6 Quote + Invoice
- Method/URL: `POST /api/promo/backoffice/requests/{pk}/quote/`
- Auth: backoffice promo
- Request JSON:
```json
{ "quote_note": "سعر بعد المراجعة" }
```
- Success `200`: تفاصيل الطلب بعد التسعير (status غالبًا `pending_payment` + invoice).
- Errors:
  - `400`: لا assets أو مرحلة غير مناسبة.
  - `401/403/404`.

### 4.7 Reject
- Method/URL: `POST /api/promo/backoffice/requests/{pk}/reject/`
- Auth: backoffice promo
- Request JSON:
```json
{ "reject_reason": "المحتوى غير مطابق" }
```
- Success `200`: تفاصيل الطلب بعد الرفض.
- Errors: `400/401/403/404`.

---

## 5) Extras - `/api/extras/`

### 5.1 الكتالوج
- Method/URL: `GET /api/extras/catalog/`
- Auth: مطلوب
- Success `200`:
```json
[
  { "sku": "uploads_10gb_month", "title": "زيادة سعة مرفقات 10GB (شهري)", "price": "59.00" },
  { "sku": "vip_support_month", "title": "دعم VIP (شهري)", "price": "149.00" }
]
```
- Errors: `401`.

### 5.2 مشترياتي
- Method/URL: `GET /api/extras/my/`
- Auth: مطلوب
- Success `200`: Array `ExtraPurchaseSerializer`.
- Errors: `401`.

### 5.3 شراء إضافة
- Method/URL: `POST /api/extras/buy/{sku}/`
- Auth: مطلوب
- Request JSON: `{}`
- Success `201`: `ExtraPurchaseSerializer` (مع `invoice`).
- Errors:
  - `400`: SKU غير موجود أو سعر غير صالح.
  - `401`.

---

## 6) Support - `/api/support/`

### 6.1 فرق الدعم
- Method/URL: `GET /api/support/teams/`
- Auth: مطلوب
- Success `200`:
```json
[
  { "id": 1, "code": "tech", "name_ar": "الدعم الفني", "is_active": true, "sort_order": 1 }
]
```
- Errors: `401`.

### 6.2 إنشاء تذكرة
- Method/URL: `POST /api/support/tickets/create/`
- Auth: مطلوب
- Request JSON:
```json
{
  "ticket_type": "tech",
  "description": "تطبيق الجوال لا يفتح",
  "priority": "normal"
}
```
- Success `201`: `SupportTicketCreateSerializer` (`id`,`code`,`ticket_type`,`description`,`priority`).
- Errors:
  - `400`: وصف مفقود/طويل.
  - `401`.

### 6.3 تذاكري
- Method/URL: `GET /api/support/tickets/my/?status=&type=`
- Auth: مطلوب
- Success `200`: Array `SupportTicketDetailSerializer`.
- Errors: `401`.

### 6.4 تفاصيل تذكرة
- Method/URL: `GET /api/support/tickets/{pk}/`
- Auth: مطلوب
- Success `200`: تفاصيل كاملة (comments/attachments/status_logs).
- Errors: `401/403/404`.

### 6.5 تعليق على تذكرة
- Method/URL: `POST /api/support/tickets/{pk}/comments/`
- Auth: مطلوب
- Request JSON:
```json
{ "text": "تمت تجربة الحل", "is_internal": false }
```
- Success `201`: `SupportCommentSerializer`.
- Errors:
  - `400`: text مفقود.
  - `401/403/404`.

### 6.6 مرفق على تذكرة
- Method/URL: `POST /api/support/tickets/{pk}/attachments/`
- Auth: مطلوب
- Content-Type: `multipart/form-data`
- Fields: `file` required
- Success `201`: `SupportAttachmentSerializer`.
- Errors:
  - `400`: file مفقود أو حجم ملف أكبر من المسموح.
  - `401/403/404`.

### 6.7 Backoffice tickets
- Method/URL: `GET /api/support/backoffice/tickets/?status=&type=&priority=&q=`
- Auth: backoffice support
- Success `200`: Array `SupportTicketDetailSerializer`.
- Errors: `401/403`.

### 6.8 Assign
- Method/URL: `PATCH /api/support/backoffice/tickets/{pk}/assign/`
- Auth: backoffice support
- Request JSON:
```json
{ "assigned_team": 2, "assigned_to": 15, "note": "تم التعيين" }
```
- Success `200`: تفاصيل التذكرة بعد التعيين.
- Errors: `401/403/404`.

### 6.9 Change status
- Method/URL: `PATCH /api/support/backoffice/tickets/{pk}/status/`
- Auth: backoffice support
- Request JSON:
```json
{ "status": "in_progress", "note": "بدأت المعالجة" }
```
- Success `200`: تفاصيل التذكرة.
- Errors:
  - `400`: status مفقود.
  - `401/403/404`.

---

## 7) Features - `/api/features/`

### 7.1 ميزات المستخدم + حد الرفع
- Method/URL: `GET /api/features/my/`
- Auth: مطلوب
- Success `200`:
```json
{
  "verify_blue": false,
  "verify_green": true,
  "promo_ads": false,
  "priority_support": true,
  "max_upload_mb": 100
}
```
- Errors: `401`.

---

## 8) Messaging - `/api/messaging/` (Updated)

### 8.1 Get/Create Thread
- Method/URL: `GET /api/messaging/requests/{request_id}/thread/`
- Auth: مطلوب (مشارك في الطلب فقط)
- Success `200`:
```json
{
  "id": 33,
  "request": 120,
  "created_at": "2026-02-14T09:00:00Z"
}
```
- Errors: `401/403/404`.

### 8.2 List Messages
- Method/URL: `GET /api/messaging/requests/{request_id}/messages/`
- Auth: مطلوب
- Success `200` (paginated):
```json
{
  "count": 2,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 501,
      "sender": 7,
      "sender_phone": "05xxxxxxxx",
      "body": "مرحبا",
      "created_at": "2026-02-14T09:05:00Z",
      "read_by_ids": [11]
    }
  ]
}
```
- Note:
  - `read_by_ids` = user IDs الذين قرؤوا الرسالة.
- Errors: `401/403/404`.

### 8.3 Send Message (REST fallback)
- Method/URL: `POST /api/messaging/requests/{request_id}/messages/send/`
- Auth: مطلوب
- Request JSON:
```json
{ "body": "مرحبا" }
```
- Success `201`:
```json
{ "ok": true, "message_id": 502 }
```
- Errors:
  - `400`: body فارغ/طويل.
  - `401/403/404`.

### 8.4 Mark Read
- Method/URL: `POST /api/messaging/requests/{request_id}/messages/read/`
- Auth: مطلوب
- Request JSON: `{}`
- Success `200`:
```json
{
  "ok": true,
  "thread_id": 33,
  "marked": 2,
  "message_ids": [501, 500]
}
```
- Note:
  - `message_ids` قائمة الرسائل التي عُلّمت كمقروءة (لـ read receipts دقيقة في Flutter).
- Errors: `401/403/404`.

### 8.5 WebSocket Events
- URL: `ws(s)://<host>/ws/thread/{thread_id}/?token=<access>`
- Incoming events:
  - `message`: `{ "type":"message","id":...,"text":"...","sender_id":...,"sent_at":"..." }`
  - `typing`: `{ "type":"typing","user_id":...,"is_typing":true }`
  - `read`: `{ "type":"read","user_id":...,"marked":2,"message_ids":[501,500] }`
- Outgoing payloads:
  - send message: `{ "type":"message","text":"..." }`
  - typing: `{ "type":"typing","is_typing":true|false }`
  - read: `{ "type":"read" }`

---

## ملاحظة 409
- في الوحدات أعلاه لا يوجد حاليًا استخدام صريح واسع لـ `409` (Conflict) باستثناء أنماط مشابهة في marketplace.
- إن احتجنا تعارضات (duplicate webhook event id / duplicate active request) يوصى بإرجاع `409` صريح.
