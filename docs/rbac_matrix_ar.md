# RBAC Matrix (Endpoint -> Role -> Completion -> Ownership)

| Endpoint | Min Role / Permission | Requires completion? | Ownership required? | Notes |
|---|---|---|---|---|
| `POST /api/accounts/otp/send/` | AllowAny | No | No | Throttle otp |
| `POST /api/accounts/otp/verify/` | AllowAny | No | No | يصدر JWT |
| `POST /api/accounts/complete/` | Authenticated | N/A | Self | يرفع إلى client |
| `POST /api/providers/register/` | `IsAtLeastPhoneOnly` | No (phone_only يكفي) | Self | يرفع إلى provider |
| `GET /api/providers/me/profile/` | `IsAtLeastClient` | Yes | Self provider profile | 404 إذا لا profile |
| `POST /api/marketplace/requests/create/` | `IsAtLeastClient` | Yes | Self as client | إنشاء طلب |
| `GET /api/marketplace/client/requests/` | `IsAtLeastClient` | Yes | Self as client | قائمة طلبات العميل |
| `GET /api/marketplace/client/requests/{id}/` | `IsAtLeastClient` | Yes | Yes (client=request.owner) | |
| `POST /api/marketplace/requests/{id}/cancel/` | `IsAuthenticated` | No (فعليًا client) | Yes (client only) | 403 otherwise |
| `POST /api/marketplace/requests/{id}/offers/create/` | Auth + `IsProviderPermission` | Provider profile | Provider eligibility | للطلبات competitive |
| `POST /api/marketplace/offers/{id}/accept/` | `IsAuthenticated` | No | Yes (request.client) | |
| `GET /api/marketplace/provider/requests/` | Auth + `IsProviderPermission` | Provider profile | Provider scope | |
| `POST /api/marketplace/provider/requests/{id}/accept/` | Auth + `IsProviderPermission` | Provider profile | Yes (assigned provider) | |
| `POST /api/marketplace/provider/requests/{id}/reject/` | Auth + `IsProviderPermission` | Provider profile | Yes (assigned provider) | |
| `POST /api/marketplace/requests/urgent/accept/` | Auth + `IsProviderPermission` | Provider profile | No direct ownership | eligibility checks city/subcategory |
| `POST /api/marketplace/requests/{id}/start/` | Auth + `IsProviderPermission` | Provider profile | Yes (assigned provider) | |
| `POST /api/marketplace/requests/{id}/complete/` | Auth + `IsProviderPermission` | Provider profile | Yes (assigned provider) | |
| `GET/POST /api/messaging/requests/{id}/thread/` | Auth + `IsRequestParticipant` | No | Yes (client/provider participant) | |
| `GET /api/messaging/requests/{id}/messages/` | Auth + `IsRequestParticipant` | No | Yes | |
| `POST /api/messaging/requests/{id}/messages/send/` | Auth + `IsRequestParticipant` | No | Yes | |
| `POST /api/messaging/requests/{id}/messages/read/` | Auth + `IsRequestParticipant` | No | Yes | |
| `WS /ws/requests/{id}/?token=` | JWT participant check | No | Yes | close 4401/4403 |
| `GET /api/billing/invoices/my/` | Authenticated | No | Self invoices only | |
| `POST /api/billing/invoices/` | Authenticated | No | Self (invoice.user=request.user) | |
| `GET /api/billing/invoices/{id}/` | Auth + `IsInvoiceOwner` | No | Yes | 403 if not owner |
| `POST /api/billing/invoices/{id}/init-payment/` | Authenticated | No | Yes (invoice.user=request.user) | |
| `POST /api/billing/webhooks/{provider}/` | Public webhook | No | No | system-to-system |
| `GET /api/subscriptions/plans/` | Authenticated | No | No | |
| `GET /api/subscriptions/my/` | Authenticated | No | Self | |
| `POST /api/subscriptions/subscribe/{plan_id}/` | Authenticated | No | Self | creates invoice |
| `POST /api/verification/requests/create/` | Auth + `IsOwnerOrBackofficeVerify` | No | Self (non-backoffice) | requires feature flag |
| `GET /api/verification/requests/my/` | Auth + `IsOwnerOrBackofficeVerify` | No | Self | |
| `GET /api/verification/requests/{id}/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `POST /api/verification/requests/{id}/documents/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `GET /api/verification/backoffice/requests/` | Backoffice verify access | N/A | Backoffice scope | admin/power/user/qa |
| `PATCH /api/verification/backoffice/documents/{id}/decision/` | Backoffice verify | N/A | Backoffice scope | QA read-only blocked |
| `POST /api/verification/backoffice/requests/{id}/finalize/` | Backoffice verify | N/A | Backoffice scope | |
| `POST /api/promo/requests/create/` | Auth + `IsOwnerOrBackofficePromo` | No | Self | requires `promo_ads` feature |
| `GET /api/promo/requests/my/` | Auth + promo permission | No | Self | |
| `GET /api/promo/requests/{id}/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `POST /api/promo/requests/{id}/assets/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `GET /api/promo/backoffice/requests/` | Backoffice promo access | N/A | Backoffice scope | |
| `POST /api/promo/backoffice/requests/{id}/quote/` | Backoffice promo access | N/A | Backoffice scope | |
| `POST /api/promo/backoffice/requests/{id}/reject/` | Backoffice promo access | N/A | Backoffice scope | |
| `GET /api/extras/catalog/` | Authenticated | No | No | |
| `GET /api/extras/my/` | Authenticated | No | Self | |
| `POST /api/extras/buy/{sku}/` | Authenticated | No | Self | creates invoice |
| `GET /api/support/teams/` | Auth + `IsRequesterOrBackofficeSupport` | No | No | |
| `POST /api/support/tickets/create/` | Auth + support permission | No | Self | |
| `GET /api/support/tickets/my/` | Auth + support permission | No | Self | |
| `GET /api/support/tickets/{id}/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `POST /api/support/tickets/{id}/comments/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `POST /api/support/tickets/{id}/attachments/` | Auth + object permission | No | Yes (owner/backoffice) | |
| `GET /api/support/backoffice/tickets/` | Backoffice support access | N/A | Backoffice scope | |
| `PATCH /api/support/backoffice/tickets/{id}/assign/` | Backoffice support access | N/A | Backoffice scope | |
| `PATCH /api/support/backoffice/tickets/{id}/status/` | Backoffice support access | N/A | Backoffice scope | |
| `GET /api/features/my/` | Authenticated | No | Self computed | source for `max_upload_mb` |

## Activation Flows (System)
- Trigger: `post_save(Invoice)` عندما `status=paid`.
- No user endpoint مباشر.
- Mapping by `reference_type`:
  - `subscription` -> activate subscription
  - `verify_request` -> activate verification badge
  - `promo_request` -> activate promo campaign
  - `extra_purchase` -> activate extra
