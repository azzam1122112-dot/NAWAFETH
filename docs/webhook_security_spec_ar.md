# Webhook Security Spec (Billing)

## 1) الحالة الحالية في الكود (As-Is)

### 1.1 استقبال webhook بدون Auth
```python
class WebhookReceiverView(APIView):
    authentication_classes = []
    permission_classes = []
```
المصدر: `backend/apps/billing/views.py`

### 1.2 يتم قراءة التوقيع لكن لا يتم التحقق منه
```python
signature = request.headers.get("X-Signature", "")
event_id = request.headers.get("X-Event-Id", "")
result = handle_webhook(provider=provider, payload=payload, signature=signature, event_id=event_id)
```
المصدر: `backend/apps/billing/views.py`

### 1.3 يتم تخزين الـWebhook raw
```python
WebhookEvent.objects.create(
    provider=provider,
    event_id=(event_id or "")[:120],
    signature=(signature or "")[:200],
    payload=payload or {},
)
```
المصدر: `backend/apps/billing/services.py`

### 1.4 النتيجة الحالية
- يوجد Logging وتخزين للأحداث.
- لا يوجد signature verification فعلي.
- لا يوجد replay-protection صارم.
- لا يوجد unique constraint على `(provider, event_id)`.

---

## 2) المواصفة المطلوبة قبل الإنتاج (To-Be)

## 2.1 Headers إلزامية
- `X-Event-Id`: معرف حدث فريد من مزود الدفع.
- `X-Timestamp`: Unix timestamp (ثوانٍ).
- `X-Signature`: HMAC SHA-256 hex.

## 2.2 Signing Algorithm
- Canonical string:
  - `canonical = "{timestamp}.{event_id}.{raw_body}"`
- Signature:
  - `expected = HMAC_SHA256(secret, canonical)`
- Secret source:
  - env var per provider, مثل: `WEBHOOK_SECRET_MOCK` أو `WEBHOOK_SECRET_<PROVIDER>`.

## 2.3 Validation Rules
1. Reject إذا header ناقص (`400`).
2. Reject إذا timestamp أقدم من 5 دقائق (`401`) لمنع replay.
3. Reject إذا signature mismatch (`401`).
4. Reject إذا `event_id` مكرر لنفس provider (`409` أو `200 idempotent-ignore` حسب السياسة).

## 2.4 Replay Protection
- نافذة قبول زمنية: `±300` ثانية.
- تخزين `(provider,event_id,received_at)` مع فهرس/قيد فريد.

## 2.5 Idempotency Rules
- If duplicate `event_id` received:
  - لا تعاد أي side-effects على الفاتورة/الاشتراك.
  - return deterministic response: `{ok:true, status:"duplicate_ignored"}`.
- If invoice already `paid` and event says `paid`:
  - no-op idempotent, return `{ok:true, status:"already_paid"}`.

## 2.6 Error Mapping
- `400`: malformed payload أو headers ناقصة.
- `401`: signature invalid أو timestamp خارج النافذة.
- `404`: event references unknown invoice/attempt (اختياري).
- `409`: duplicate event_id (إن اعتمدنا conflict policy).

---

## 3) تعديلات Schema مقترحة

### 3.1 على `WebhookEvent`
- إضافة قيد فريد:
  - `UniqueConstraint(fields=["provider", "event_id"], name="uniq_webhook_provider_event")`
- إضافة حقل:
  - `is_verified = models.BooleanField(default=False)`
  - `verification_error = models.CharField(max_length=200, blank=True)`

### 3.2 على `PaymentAttempt` (اختياري)
- إضافة index مركب `(provider, provider_reference, status)` لتسريع lookup.

---

## 4) سياسة معالجة webhook غير الصحيح/المكرر
- غير صحيح (توقيع/وقت):
  - لا تعديل بيانات مالية.
  - سجل event كـ `is_verified=False` مع سبب.
  - return `401`.
- مكرر:
  - لا تعديل بيانات.
  - return deterministic payload.

---

## 5) نقطة ربط مع النظام الحالي
- activation signals تعمل بعد تحويل invoice إلى `paid`:
  - `subscriptions/signals.py`
  - `verification/signals.py`
  - `promo/signals.py`
  - `extras/signals.py`

لذلك حماية webhook شرط أساسي قبل Go-Live.
