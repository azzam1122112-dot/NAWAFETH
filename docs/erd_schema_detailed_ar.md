# ERD Schema تفصيلي (حقول + قيود + علاقات)

> المصدر: `models.py` الفعلية في المشروع.

## A) Billing

### `billing_invoice`
- `id`: BigAutoField PK
- `code`: Char(20), `unique=True`, blank allowed at create, generated after save
- `user_id`: FK -> `accounts_user.id`, required, `on_delete=CASCADE`
- `title`: Char(160), default "فاتورة"
- `description`: Char(300), blank
- `currency`: Char(10), default `SAR`
- `subtotal`: Decimal(12,2), default `0.00`
- `vat_percent`: Decimal(5,2), default `15.00`
- `vat_amount`: Decimal(12,2), default `0.00`
- `total`: Decimal(12,2), default `0.00`
- `status`: Char(20), choices: `draft|pending|paid|failed|cancelled|refunded`
- `reference_type`: Char(50), blank
- `reference_id`: Char(50), blank
- `paid_at`: DateTime nullable
- `cancelled_at`: DateTime nullable
- `created_at`, `updated_at`
- Notes:
  - amounts recalculated on save (`recalc()`)
  - code format: `IV%06d`

### `billing_paymentattempt`
- `id`: UUID PK
- `invoice_id`: FK -> `billing_invoice.id`, required, `CASCADE`
- `provider`: Char(30), choices: `manual|mock`
- `status`: Char(20), choices: `initiated|redirected|success|failed|cancelled`
- `idempotency_key`: Char(80), blank
- `amount`: Decimal(12,2)
- `currency`: Char(10)
- `checkout_url`: URL, blank
- `provider_reference`: Char(120), blank
- `request_payload`: JSON
- `response_payload`: JSON
- `created_by_id`: FK -> `accounts_user.id`, nullable, `SET_NULL`
- `created_at`
- Indexes:
  - `(provider, provider_reference)`
  - `(idempotency_key)`

### `billing_webhookevent`
- `id`: BigAutoField PK
- `provider`: Char(30), choices `manual|mock`
- `event_id`: Char(120), blank
- `signature`: Char(200), blank
- `payload`: JSON
- `received_at`
- Indexes: `(provider, event_id)`

## B) Subscriptions

### `subscriptions_subscriptionplan`
- `id`: BigAutoField PK
- `code`: Char(30), `unique=True`
- `title`: Char(80)
- `description`: Char(300), blank
- `period`: Char(10), choices `month|year`
- `price`: Decimal(12,2)
- `features`: JSON list
- `is_active`: Bool
- `created_at`
- Ordering: `price, id`

### `subscriptions_subscription`
- `id`: BigAutoField PK
- `user_id`: FK -> `accounts_user.id`, `CASCADE`
- `plan_id`: FK -> `subscriptions_subscriptionplan.id`, `PROTECT`
- `status`: Char(20), choices `pending_payment|active|grace|expired|cancelled`
- `start_at`, `end_at`, `grace_end_at`: nullable DateTime
- `auto_renew`: Bool default true
- `invoice_id`: FK -> `billing_invoice.id`, nullable, `SET_NULL`
- `created_at`, `updated_at`

## C) Verification

### `verification_verificationrequest`
- `id`: BigAutoField PK
- `code`: Char(20), `unique=True`, generated (`AD%06d`)
- `requester_id`: FK -> `accounts_user.id`, `CASCADE`
- `badge_type`: Char(20), choices `blue|green`
- `status`: Char(25), choices `new|in_review|rejected|approved|pending_payment|active|expired`
- `admin_note`: Char(300), blank
- `reject_reason`: Char(300), blank
- `invoice_id`: FK -> `billing_invoice.id`, nullable, `SET_NULL`
- `requested_at`, `reviewed_at`, `approved_at`, `activated_at`, `expires_at`, `updated_at`

### `verification_verificationdocument`
- `id`: BigAutoField PK
- `request_id`: FK -> `verification_verificationrequest.id`, `CASCADE`
- `doc_type`: Char(30), choices `id|cr|iban|license|other`
- `title`: Char(160), blank
- `file`: FileField
- `is_approved`: Bool nullable
- `decision_note`: Char(300), blank
- `decided_by_id`: FK -> `accounts_user.id`, nullable, `SET_NULL`
- `decided_at`: DateTime nullable
- `uploaded_by_id`: FK -> `accounts_user.id`, nullable, `SET_NULL`
- `uploaded_at`

### `verification_verifiedbadge`
- `id`: BigAutoField PK
- `user_id`: FK -> `accounts_user.id`, `CASCADE`
- `badge_type`: Char(20), choices `blue|green`
- `request_id`: FK -> `verification_verificationrequest.id`, `CASCADE`
- `activated_at`, `expires_at`
- `is_active`: Bool
- `created_at`
- Indexes: `(user, badge_type, is_active)`

## D) Promo

### `promo_promorequest`
- `id`: BigAutoField PK
- `code`: Char(20), `unique=True`, generated (`MD%06d`)
- `requester_id`: FK -> `accounts_user.id`, `CASCADE`
- `title`: Char(160)
- `ad_type`: Char(30), choices متعددة (banner/popup/featured/boost/push)
- `start_at`, `end_at`: DateTime
- `frequency`: Char(10), choices `10s|20s|30s|60s`
- `position`: Char(10), choices `first|second|top5|top10|normal`
- `target_category`: Char(80), blank
- `target_city`: Char(80), blank
- `redirect_url`: URL, blank
- `status`: Char(25), choices `new|in_review|quoted|pending_payment|active|rejected|expired|cancelled`
- `subtotal`: Decimal(12,2)
- `total_days`: PositiveInteger
- `quote_note`: Char(300), blank
- `reject_reason`: Char(300), blank
- `invoice_id`: FK -> `billing_invoice.id`, nullable `SET_NULL`
- `reviewed_at`, `activated_at`, `created_at`, `updated_at`

### `promo_promoasset`
- `id`: BigAutoField PK
- `request_id`: FK -> `promo_promorequest.id`, `CASCADE`
- `asset_type`: Char(20), choices `image|video|pdf|other`
- `title`: Char(160), blank
- `file`: FileField
- `uploaded_by_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `uploaded_at`

## E) Extras

### `extras_extrapurchase`
- `id`: BigAutoField PK
- `user_id`: FK -> `accounts_user.id`, `CASCADE`
- `sku`: Char(80)
- `title`: Char(160)
- `extra_type`: Char(20), choices `time_based|credit_based`
- `subtotal`: Decimal(12,2)
- `currency`: Char(10), default `SAR`
- `start_at`, `end_at`: nullable DateTime
- `credits_total`, `credits_used`: PositiveInteger
- `status`: Char(20), choices `pending_payment|active|consumed|expired|cancelled`
- `invoice_id`: FK -> `billing_invoice.id`, nullable `SET_NULL`
- `created_at`, `updated_at`

## F) Support

### `support_supportteam`
- `id`: BigAutoField PK
- `code`: Slug(50), `unique=True`
- `name_ar`: Char(120)
- `is_active`: Bool
- `sort_order`: PositiveInteger
- Ordering: `sort_order, id`

### `support_supportticket`
- `id`: BigAutoField PK
- `code`: Char(20), `unique=True`, generated `HD%06d`
- `requester_id`: FK -> `accounts_user.id`, `CASCADE`
- `ticket_type`: Char(20), choices `tech|subs|verify|suggest|ads|complaint|extras`
- `status`: Char(20), choices `new|in_progress|returned|closed`
- `priority`: Char(20), choices `low|normal|high`
- `description`: Char(300)
- `assigned_team_id`: FK -> `support_supportteam.id`, nullable `SET_NULL`
- `assigned_to_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `assigned_at`, `returned_at`, `closed_at`: nullable DateTime
- `last_action_by_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `created_at`, `updated_at`

### `support_supportattachment`
- `id`: BigAutoField PK
- `ticket_id`: FK -> `support_supportticket.id`, `CASCADE`
- `file`: FileField
- `uploaded_by_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `created_at`

### `support_supportcomment`
- `id`: BigAutoField PK
- `ticket_id`: FK -> `support_supportticket.id`, `CASCADE`
- `text`: Char(300)
- `is_internal`: Bool
- `created_by_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `created_at`

### `support_supportstatuslog`
- `id`: BigAutoField PK
- `ticket_id`: FK -> `support_supportticket.id`, `CASCADE`
- `from_status`, `to_status`: Char(20), choices ticket status
- `changed_by_id`: FK -> `accounts_user.id`, nullable `SET_NULL`
- `note`: Char(200), blank
- `created_at`
- Ordering: `-id`

## G) Features (Runtime وليس جداول)
- endpoint: `/api/features/my/`
- الناتج computed من:
  - `subscriptions_subscription` + `subscriptions_subscriptionplan.features`
  - `extras_extrapurchase`
- قيمة `max_upload_mb` مشتقة ديناميكيًا.

## H) علاقات تشغيلية حرجة
- Invoice activation signals:
  - `reference_type=subscription` -> تفعيل اشتراك.
  - `reference_type=verify_request` -> تفعيل توثيق.
  - `reference_type=promo_request` -> تفعيل حملة.
  - `reference_type=extra_purchase` -> تفعيل إضافة.
