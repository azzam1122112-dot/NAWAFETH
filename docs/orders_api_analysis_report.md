# Orders / Service Requests — Comprehensive API & Model Analysis

> Generated: 2026-02-28 | Modules analysed: `marketplace`, `unified_requests`, `providers`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Backend Models](#2-backend-models)
3. [API Endpoints — Full Reference](#3-api-endpoints--full-reference)
4. [Serializer Field Maps](#4-serializer-field-maps)
5. [Mobile Screen ↔ API Mapping](#5-mobile-screen--api-mapping)
6. [Gap Analysis (Mock vs Real API)](#6-gap-analysis-mock-vs-real-api)

---

## 1. Architecture Overview

| Layer | Module | Role |
|-------|--------|------|
| **API + Models** | `apps.marketplace` | Core orders/service-requests CRUD, offers, status transitions — **all order endpoints live here** |
| **Service Engine** | `apps.unified_requests` | Internal back-office unified request tracker. No API endpoints. Used by support/promo/verification modules to track internal tickets. **Not used by mobile order screens.** |
| **Profiles** | `apps.providers` | Provider profiles, services, portfolio. No order-related views. References `marketplace.RequestStatus` for computing `completed_requests` on provider cards. |

### URL Prefix

All marketplace endpoints are mounted at:

```
/api/marketplace/  →  apps.marketplace.urls
```

(Defined in `config/urls.py`)

---

## 2. Backend Models

### 2.1 `marketplace.ServiceRequest` (the main "Order" model)

| Field | Type | Notes |
|-------|------|-------|
| `id` | AutoField (PK) | Integer, auto-incremented |
| `client` | FK → `User` | The customer who placed the request |
| `provider` | FK → `ProviderProfile` (nullable) | Assigned service provider |
| `subcategory` | FK → `SubCategory` | Service category |
| `title` | CharField(50) | Request title |
| `description` | TextField(500) | Request details |
| `request_type` | CharField(20) | `normal` / `competitive` / `urgent` |
| `status` | CharField(20) | `new` / `in_progress` / `completed` / `cancelled` |
| `city` | CharField(100) | Service city |
| `is_urgent` | BooleanField | Auto-set when `request_type=urgent` |
| `created_at` | DateTimeField (auto) | |
| `expires_at` | DateTimeField (nullable) | Only for urgent requests (default 15 min) |
| `quote_deadline` | DateField (nullable) | Deadline for competitive offers |
| `expected_delivery_at` | DateTimeField (nullable) | Set by provider on start |
| `estimated_service_amount` | Decimal(12,2) (nullable) | Provider's estimated cost |
| `received_amount` | Decimal(12,2) (nullable) | Advance payment received |
| `remaining_amount` | Decimal(12,2) (nullable) | Auto-computed: estimated − received |
| `delivered_at` | DateTimeField (nullable) | Set on completion |
| `actual_service_amount` | Decimal(12,2) (nullable) | Final cost on completion |
| `canceled_at` | DateTimeField (nullable) | |
| `cancel_reason` | CharField(255) | |
| `provider_inputs_approved` | BooleanField (nullable) | Client approval of provider inputs |
| `provider_inputs_decided_at` | DateTimeField (nullable) | |
| `provider_inputs_decision_note` | CharField(255) | |

#### Status Flow

```
                    ┌─────────────┐
                    │    NEW      │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        Provider       Provider     (expires/
        accepts        rejects      client cancels)
              │            │            │
              ▼            ▼            ▼
       ┌─────────────┐  ┌──────────┐  ┌──────────┐
       │ IN_PROGRESS  │  │CANCELLED │  │CANCELLED │
       └──────┬──────┘  └──────────┘  └──────────┘
              │
        Provider completes
              │
              ▼
       ┌─────────────┐
       │  COMPLETED   │
       └─────────────┘
```

### 2.2 `marketplace.Offer` (Competitive request bids)

| Field | Type | Notes |
|-------|------|-------|
| `id` | AutoField (PK) | |
| `request` | FK → `ServiceRequest` | |
| `provider` | FK → `ProviderProfile` | Unique together with request |
| `price` | Decimal(10,2) | |
| `duration_days` | PositiveInt | |
| `note` | TextField(500) | |
| `status` | CharField(20) | `pending` / `selected` / `rejected` |
| `created_at` | DateTimeField (auto) | |

### 2.3 `marketplace.RequestStatusLog`

| Field | Type |
|-------|------|
| `id` | AutoField |
| `request` | FK → `ServiceRequest` |
| `actor` | FK → `User` (nullable) |
| `from_status` | CharField(20) |
| `to_status` | CharField(20) |
| `note` | CharField(255) |
| `created_at` | DateTimeField |

### 2.4 `marketplace.ServiceRequestAttachment`

| Field | Type | Notes |
|-------|------|-------|
| `id` | AutoField | |
| `request` | FK → `ServiceRequest` | |
| `file` | FileField | `requests/attachments/%Y/%m/%d/` |
| `file_type` | CharField(20) | `image` / `video` / `audio` / `document` |
| `created_at` | DateTimeField | |

### 2.5 `unified_requests.UnifiedRequest` (Back-office only — NO mobile API)

Internal ticket aggregator for support/promo/verification. Types: `helpdesk`, `promo`, `verification`, `subscription`, `extras`, `reviews`. Has its own status flow, metadata, assignment logs, and status logs.

**Not exposed via any API endpoint. Used internally by `upsert_unified_request()` service function.**

---

## 3. API Endpoints — Full Reference

All paths below are prefixed with `/api/marketplace/`.

### 3.1 Request Creation

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 1 | **POST** | `requests/create/` | `ServiceRequestCreateView` | `IsAtLeastClient` | Create a service request |

**Request Body (multipart/form-data):**

```json
{
  "provider": 5,                    // int (required for normal, forbidden for competitive/urgent)
  "subcategory": 3,                 // int (required)
  "title": "تصميم فيلا",           // string max 50 (required)
  "description": "...",             // string max 500 (required)
  "request_type": "normal",         // "normal" | "competitive" | "urgent" (required)
  "city": "الرياض",                // string (required except urgent+all)
  "dispatch_mode": "all",           // "all" | "nearest" (optional, urgent only)
  "quote_deadline": "2026-03-15",   // date (optional, competitive)
  "images": [File, ...],            // optional
  "videos": [File, ...],            // optional
  "files": [File, ...],             // optional
  "audio": File                     // optional
}
```

**Response: 201 Created** — Created `ServiceRequest` object (id, title, status, etc.)

**Validation Rules:**
- `normal` → `provider` required, `city` must match provider city, subcategory must be in provider's categories
- `competitive` / `urgent` → `provider` must NOT be set
- `city` required unless `urgent` + `dispatch_mode=all`

---

### 3.2 Client Endpoints

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 2 | **GET** | `client/requests/` | `MyClientRequestsView` | `IsAtLeastClient` | List client's own requests |
| 3 | **GET** | `client/requests/<request_id>/` | `MyClientRequestDetailView` | `IsAtLeastClient` | Get request detail (with attachments + status logs) |
| 4 | **PATCH/PUT** | `client/requests/<request_id>/` | `MyClientRequestDetailView` | `IsAtLeastClient` | Update title/description (only when status=new) |

##### GET `client/requests/` — Query Parameters

| Param | Description |
|-------|-------------|
| `status_group` | `new` / `in_progress` / `completed` / `cancelled` (also accepts Arabic: جديد, تحت التنفيذ, مكتمل, ملغي) |
| `status` | Raw status value: `new` / `in_progress` / `completed` / `cancelled` |
| `type` | `normal` / `competitive` / `urgent` |
| `q` | Full-text search on title, description, subcategory name, category name |

**Response: 200 OK** — Array of `ServiceRequestListSerializer`:

```json
[
  {
    "id": 1,
    "client_id": 10,
    "title": "تصميم فيلا خاصة",
    "description": "...",
    "request_type": "normal",
    "status": "new",
    "status_group": "new",
    "status_label": "جديد",
    "city": "الرياض",
    "created_at": "2026-01-01T16:35:00Z",
    "provider": 5,
    "provider_name": "شركة التصميم",
    "provider_phone": "0501234567",
    "quote_deadline": null,
    "expected_delivery_at": null,
    "estimated_service_amount": null,
    "received_amount": null,
    "remaining_amount": null,
    "delivered_at": null,
    "actual_service_amount": null,
    "canceled_at": null,
    "cancel_reason": "",
    "provider_inputs_approved": null,
    "provider_inputs_decided_at": null,
    "provider_inputs_decision_note": "",
    "review_id": null,
    "review_rating": null,
    "review_response_speed": null,
    "review_cost_value": null,
    "review_quality": null,
    "review_credibility": null,
    "review_on_time": null,
    "review_comment": null,
    "subcategory": 3,
    "subcategory_name": "تصميم معماري",
    "category_name": "هندسة وتصميم",
    "client_name": "أحمد العتيبي",
    "client_phone": "0501234567"
  }
]
```

##### GET `client/requests/<id>/` — Detail Response (extends list + adds):

```json
{
  "...all list fields...",
  "attachments": [
    { "id": 1, "file_type": "image", "file_url": "/media/requests/...", "created_at": "..." }
  ],
  "status_logs": [
    { "id": 1, "from_status": "", "to_status": "new", "note": "...", "created_at": "...", "actor_name": "أحمد" }
  ]
}
```

##### PATCH `client/requests/<id>/` — Update Body

```json
{
  "title": "عنوان جديد",      // optional
  "description": "تفاصيل جديدة"  // optional
}
```

Only allowed when `status` is `new` (or `sent`). Returns full detail object. Creates a `RequestStatusLog` entry.

---

### 3.3 Provider Endpoints

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 5 | **GET** | `provider/requests/` | `MyProviderRequestsView` | Authenticated + Provider | List provider's assigned requests |
| 6 | **GET** | `provider/requests/<request_id>/detail/` | `ProviderRequestDetailView` | Authenticated + Provider | Get request detail |
| 7 | **POST** | `provider/requests/<request_id>/accept/` | `ProviderAssignedRequestAcceptView` | Authenticated + Provider | Accept an assigned (normal) request |
| 8 | **POST** | `provider/requests/<request_id>/reject/` | `ProviderAssignedRequestRejectView` | Authenticated + Provider | Reject/cancel an assigned request |
| 9 | **POST** | `provider/requests/<request_id>/progress-update/` | `ProviderProgressUpdateView` | Authenticated + Provider | Update execution details during in_progress |

##### GET `provider/requests/` — Query Parameters

| Param | Description |
|-------|-------------|
| `status_group` | `new` / `in_progress` / `completed` / `cancelled` |
| `client_user_id` | Filter by specific client |

**Response:** Same `ServiceRequestListSerializer` array as client list.

##### POST `provider/requests/<id>/accept/`

No body required. Changes status `new` → `in_progress`. Returns `{ "ok": true, "request_id": N, "status": "in_progress" }`.

Only for normal/urgent assigned requests (not competitive — those use offers).

##### POST `provider/requests/<id>/reject/`

```json
{
  "canceled_at": "2026-01-05T09:30:00Z",
  "cancel_reason": "سبب الإلغاء",
  "note": "ملاحظة اختيارية"          // optional
}
```

Changes status → `cancelled`. Returns `{ "ok": true, "request_id": N, "status": "cancelled" }`.

##### POST `provider/requests/<id>/progress-update/`

```json
{
  "expected_delivery_at": "2026-02-01T18:00:00Z",  // optional
  "estimated_service_amount": "1500.00",             // optional (must pair with received_amount)
  "received_amount": "500.00",                       // optional (must pair with estimated)
  "note": "تحديث"                                   // optional (required if no other fields)
}
```

Only during `in_progress`. Auto-computes `remaining_amount`. Returns `{ "ok": true }`.

---

### 3.4 Urgent Request Endpoints

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 10 | **GET** | `provider/urgent/available/` | `AvailableUrgentRequestsView` | Authenticated + Provider | List available urgent requests matching provider's city + subcategories |
| 11 | **POST** | `requests/urgent/accept/` | `UrgentRequestAcceptView` | Authenticated + Provider | Claim an urgent request |

##### POST `requests/urgent/accept/`

```json
{ "request_id": 42 }
```

Atomically claims the request (sets provider + status=in_progress). Validates: not expired, city match, subcategory match, `accepts_urgent=true`.

Returns `{ "ok": true, "request_id": 42, "status": "in_progress", "provider": "اسم المزود" }`.

---

### 3.5 Competitive Request Endpoints

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 12 | **GET** | `provider/competitive/available/` | `AvailableCompetitiveRequestsView` | Authenticated + Provider | List available competitive requests |

---

### 3.6 Status Transition Endpoints

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 13 | **POST** | `requests/<request_id>/start/` | `RequestStartView` | Authenticated + Provider | Start execution (new → in_progress with financial inputs) |
| 14 | **POST** | `requests/<request_id>/complete/` | `RequestCompleteView` | Authenticated + Provider | Complete request (in_progress → completed) |
| 15 | **POST** | `requests/<request_id>/cancel/` | `RequestCancelView` | `IsAtLeastClient` | **DISABLED** — returns 403 "client cancel not available" |
| 16 | **POST** | `requests/<request_id>/reopen/` | `RequestReopenView` | `IsAtLeastClient` | **DISABLED** — returns 403 "reopen not supported" |
| 17 | **POST** | `requests/<request_id>/provider-inputs/decision/` | `ProviderInputsDecisionView` | `IsAtLeastClient` | **DISABLED** — returns 403 |

##### POST `requests/<id>/start/`

```json
{
  "expected_delivery_at": "2026-02-10T18:00:00Z",
  "estimated_service_amount": "1500.00",
  "received_amount": "500.00",
  "note": "بدء التنفيذ"               // optional
}
```

Provider sends execution parameters. Auto-computes `remaining_amount`. Resets `provider_inputs_approved`. Returns `{ "ok": true }`.

##### POST `requests/<id>/complete/`

```json
{
  "delivered_at": "2026-02-08T13:00:00Z",
  "actual_service_amount": "950.00",
  "note": "تم الإنجاز"              // optional
}
```

---

### 3.7 Offers (Competitive Requests)

| # | Method | Path | View | Auth | Description |
|---|--------|------|------|------|-------------|
| 18 | **POST** | `requests/<request_id>/offers/create/` | `CreateOfferView` | Authenticated + Provider | Submit an offer on a competitive request |
| 19 | **GET** | `requests/<request_id>/offers/` | `RequestOffersListView` | `IsAtLeastClient` | List offers on a request (client only) |
| 20 | **POST** | `offers/<offer_id>/accept/` | `AcceptOfferView` | `IsAtLeastClient` | Accept an offer (assigns provider to request) |

##### POST `requests/<id>/offers/create/`

```json
{
  "price": "1200.00",
  "duration_days": 7,
  "note": "عرضي للخدمة"
}
```

Returns `{ "ok": true, "offer_id": N }` (201) or `{ "detail": "تم إرسال عرض مسبقًا" }` (409).

##### GET `requests/<id>/offers/`

```json
[
  {
    "id": 1,
    "provider": 5,
    "provider_name": "شركة التصميم",
    "price": "1200.00",
    "duration_days": 7,
    "note": "...",
    "status": "pending",
    "created_at": "..."
  }
]
```

##### POST `offers/<id>/accept/`

No body. Assigns provider to request, rejects other offers. Returns `{ "ok": true, "request_id": N }`.

---

## 4. Serializer Field Maps

### `ServiceRequestListSerializer` (used for list views)

```
id, client_id, title, description, request_type, status,
status_group (computed), status_label (computed: Arabic),
city, created_at, provider, provider_name, provider_phone,
quote_deadline, expected_delivery_at, estimated_service_amount,
received_amount, remaining_amount, delivered_at, actual_service_amount,
canceled_at, cancel_reason, provider_inputs_approved,
provider_inputs_decided_at, provider_inputs_decision_note,
review_id, review_rating, review_response_speed, review_cost_value,
review_quality, review_credibility, review_on_time, review_comment,
subcategory, subcategory_name, category_name, client_name, client_phone
```

### `ProviderRequestDetailSerializer` (extends list + adds nested data)

```
...all list fields...
+ attachments: [{ id, file_type, file_url, created_at }]
+ status_logs: [{ id, from_status, to_status, note, created_at, actor_name }]
```

### `ServiceRequestCreateSerializer`

```
id, provider, subcategory, title, description, request_type,
city, dispatch_mode (write-only), images (write-only),
videos (write-only), files (write-only), audio (write-only),
quote_deadline
```

---

## 5. Mobile Screen ↔ API Mapping

### 5.1 `ClientOrdersScreen` → `GET /api/marketplace/client/requests/`

| Mobile Mock Field | API Response Field | Notes |
|-------------------|--------------------|-------|
| `ClientOrder.id` ("R055544") | `id` (integer) | **MISMATCH**: Mobile uses string "R055544", API returns int `1` |
| `ClientOrder.serviceCode` ("@111222") | — | **MISSING from API**: No `serviceCode` concept in backend |
| `ClientOrder.createdAt` | `created_at` | ISO format |
| `ClientOrder.status` (Arabic) | `status_label` (Arabic) or `status_group` | API provides both raw and Arabic |
| `ClientOrder.title` | `title` | ✅ |
| `ClientOrder.details` | `description` | Field name differs |
| `ClientOrder.attachments` | `attachments` (only in detail) | List endpoint doesn't include attachments |
| `ClientOrder.expectedDeliveryAt` | `expected_delivery_at` | ✅ |
| `ClientOrder.serviceAmountSR` | `estimated_service_amount` | Field name differs |
| `ClientOrder.receivedAmountSR` | `received_amount` | ✅ |
| `ClientOrder.remainingAmountSR` | `remaining_amount` | ✅ |
| `ClientOrder.deliveredAt` | `delivered_at` | ✅ |
| `ClientOrder.actualServiceAmountSR` | `actual_service_amount` | ✅ |
| `ClientOrder.ratingResponseSpeed` | `review_response_speed` | From related Review model |
| `ClientOrder.ratingCostValue` | `review_cost_value` | From related Review model |
| `ClientOrder.ratingQuality` | `review_quality` | From related Review model |
| `ClientOrder.ratingCredibility` | `review_credibility` | From related Review model |
| `ClientOrder.ratingOnTime` | `review_on_time` | From related Review model |
| `ClientOrder.ratingComment` | `review_comment` | From related Review model |
| `ClientOrder.canceledAt` | `canceled_at` | ✅ |
| `ClientOrder.cancelReason` | `cancel_reason` | ✅ |
| — | `request_type` | **Mobile doesn't show** normal/competitive/urgent |
| — | `provider_name` | **Mobile doesn't display** who the provider is |
| — | `subcategory_name`, `category_name` | **Mobile doesn't show** service category |

**Filter chips mapping:**
- الكل → no `status_group` param
- جديد → `?status_group=new`
- تحت التنفيذ → `?status_group=in_progress`
- مكتمل → `?status_group=completed`
- ملغي → `?status_group=cancelled`

### 5.2 `ClientOrderDetailsScreen` → `GET /api/marketplace/client/requests/<id>/`

Uses `ProviderRequestDetailSerializer` which adds `attachments[]` and `status_logs[]`.
Client can update title/description via `PATCH /api/marketplace/client/requests/<id>/`.

### 5.3 `ProviderOrdersScreen` → `GET /api/marketplace/provider/requests/`

| Mobile Mock Field | API Response Field | Notes |
|-------------------|--------------------|-------|
| `ProviderOrder.id` | `id` (integer) | **MISMATCH**: Mock uses "R012345", API returns int |
| `ProviderOrder.serviceCode` | — | **MISSING from API** |
| `ProviderOrder.clientName` | `client_name` | ✅ |
| `ProviderOrder.clientHandle` ("@ahmed_at") | — | **MISSING**: No username/handle in serializer |
| `ProviderOrder.clientPhone` | `client_phone` | ✅ |
| `ProviderOrder.clientCity` | `city` | Request city, not client's city |
| `ProviderOrder.title` | `title` | ✅ |
| `ProviderOrder.details` | `description` | Field name differs |
| `ProviderOrder.attachments` | `attachments` (detail only) | Not in list response |
| `ProviderOrder.expectedDeliveryAt` | `expected_delivery_at` | ✅ |
| `ProviderOrder.estimatedServiceAmountSR` | `estimated_service_amount` | ✅ |
| `ProviderOrder.receivedAmountSR` | `received_amount` | ✅ |
| `ProviderOrder.remainingAmountSR` | `remaining_amount` | ✅ |
| `ProviderOrder.deliveredAt` | `delivered_at` | ✅ |
| `ProviderOrder.actualServiceAmountSR` | `actual_service_amount` | ✅ |
| `ProviderOrder.canceledAt` | `canceled_at` | ✅ |
| `ProviderOrder.cancelReason` | `cancel_reason` | ✅ |

### 5.4 `ProviderOrderDetailsScreen` → `GET /api/marketplace/provider/requests/<id>/detail/`

Provider can:
- **Accept**: `POST /api/marketplace/provider/requests/<id>/accept/`
- **Reject**: `POST /api/marketplace/provider/requests/<id>/reject/`
- **Start execution**: `POST /api/marketplace/requests/<id>/start/`
- **Update progress**: `POST /api/marketplace/provider/requests/<id>/progress-update/`
- **Complete**: `POST /api/marketplace/requests/<id>/complete/`

### 5.5 `ServiceRequestFormScreen` → `POST /api/marketplace/requests/create/`

| Mobile Form Field | API Field | Notes |
|-------------------|-----------|-------|
| `providerName` | — | Display-only (not sent) |
| `providerId` | `provider` | Required for normal type |
| `_titleController` | `title` | max 50 |
| `_detailsController` | `description` | max 500 |
| `_deadline` | `quote_deadline` | Date picker |
| `_images` | `images` | File list |
| `_videos` | `videos` | File list |
| `_files` | `files` | File list |
| `_audioPath` | `audio` | Single file |
| — | `request_type` | **Mobile doesn't have** type selector yet |
| — | `subcategory` | **Mobile doesn't have** subcategory picker yet |
| — | `city` | **Mobile doesn't have** city field yet |

---

## 6. Gap Analysis (Mock vs Real API)

### Critical Gaps to Resolve

| # | Gap | Severity | Resolution |
|---|-----|----------|------------|
| 1 | **Order ID format**: Mobile uses "R055544" string, API returns integer `id` | 🔴 High | Mobile should format display as `"R${id.toString().padLeft(6, '0')}"` or use `id` directly |
| 2 | **`serviceCode` field**: Mobile mocks "@111222" but API has no such field | 🟡 Medium | Remove from mobile or map to `subcategory` + `id` combo |
| 3 | **`clientHandle` field**: Provider order mock shows "@ahmed_at" but API doesn't return username | 🟡 Medium | Add `client_username` to `ServiceRequestListSerializer`, or remove from mobile |
| 4 | **`request_type` not shown**: Mobile doesn't display/filter by normal/competitive/urgent | 🟡 Medium | Add type badge and filter capability |
| 5 | **No `subcategory`/`city` picker** in `ServiceRequestFormScreen` | 🔴 High | Mobile form is missing required fields for request creation |
| 6 | **No `request_type` selector** in `ServiceRequestFormScreen` | 🔴 High | Mobile form always needs to specify the type |
| 7 | **Field naming**: `details` vs `description`, `serviceAmountSR` vs `estimated_service_amount` | 🟡 Medium | Map in `fromJson()` factory constructors |
| 8 | **Attachments** only in detail endpoint, not in list | 🟢 Low | Expected — fetch on detail screen |
| 9 | **`ClientOrder.ratingAttachments`**: No corresponding API field | 🟢 Low | Not supported in backend reviews |
| 10 | **Cancel/Reopen from client side**: Disabled in backend (returns 403) | ℹ️ Info | Mobile should hide reopen/cancel buttons for clients |
| 11 | **Provider name/phone** not shown on client order list | 🟡 Medium | API already provides `provider_name` + `provider_phone`, just not rendered |
| 12 | **Offers flow** not implemented in mobile | 🟡 Medium | Need screens for listing/submitting/accepting offers on competitive requests |

### What's Already Properly Aligned

- ✅ Status values and filtering (new/in_progress/completed/cancelled)
- ✅ Financial fields (estimated, received, remaining, actual amounts)
- ✅ Date fields (created, expected delivery, delivered, canceled)
- ✅ Cancel reason field
- ✅ Review/rating fields mapped from related Review model
- ✅ Attachment upload on creation (images, videos, files, audio)
- ✅ Provider accept/reject/start/complete lifecycle

---

## Appendix: Complete URL Route Table

| Full URL | Method(s) | Name |
|----------|-----------|------|
| `/api/marketplace/requests/create/` | POST | `request_create` |
| `/api/marketplace/requests/urgent/accept/` | POST | `urgent_accept` |
| `/api/marketplace/provider/urgent/available/` | GET | `provider_urgent_available` |
| `/api/marketplace/provider/competitive/available/` | GET | `provider_competitive_available` |
| `/api/marketplace/provider/requests/` | GET | `provider_requests` |
| `/api/marketplace/provider/requests/<id>/detail/` | GET | `provider_request_detail` |
| `/api/marketplace/provider/requests/<id>/accept/` | POST | `provider_request_accept` |
| `/api/marketplace/provider/requests/<id>/reject/` | POST | `provider_request_reject` |
| `/api/marketplace/provider/requests/<id>/progress-update/` | POST | `provider_request_progress_update` |
| `/api/marketplace/client/requests/` | GET | `client_requests` |
| `/api/marketplace/client/requests/<id>/` | GET, PATCH, PUT | `client_request_detail` |
| `/api/marketplace/requests/<id>/offers/create/` | POST | `offer_create` |
| `/api/marketplace/requests/<id>/offers/` | GET | `offers_list` |
| `/api/marketplace/offers/<id>/accept/` | POST | `offer_accept` |
| `/api/marketplace/requests/<id>/start/` | POST | `request_start` |
| `/api/marketplace/requests/<id>/complete/` | POST | `request_complete` |
| `/api/marketplace/requests/<id>/cancel/` | POST | `request_cancel` (disabled) |
| `/api/marketplace/requests/<id>/reopen/` | POST | `request_reopen` (disabled) |
| `/api/marketplace/requests/<id>/provider-inputs/decision/` | POST | `provider_inputs_decision` (disabled) |
| `/api/marketplace/requests/<id>/` | GET (HTML) | `request_detail` (dashboard) |
| `/api/marketplace/requests/<id>/action/` | POST (HTML) | `request_action` (dashboard) |
| `/api/marketplace/provider/requests/page/` | GET (HTML) | `provider_requests_page` (dashboard) |
