# Test Plan - Nawafeth

## 1. Authentication & Account
- OTP send/verify success/failure/expiry/throttle.
- JWT refresh flow + token expiry.
- completion gate من `phone_only` إلى `client`.

## 2. RBAC
- تحقق منع/سماح لكل endpoint حسب الدور.
- التحقق من المسارات backoffice حسب `access_profile`.

## 3. Marketplace
- normal request requires provider.
- competitive/urgent لا يسمح provider محدد.
- offer create/accept/reject scenarios.
- start/complete/cancel lifecycle validations.

## 4. Messaging
- thread creation for participants only.
- send/read permissions.
- websocket connect unauthorized/forbidden/participant.

## 5. Notifications
- unread count correctness.
- mark single/all read.
- device token registration.

## 6. Reviews
- review only when completed and owned by client.
- criteria validation (1..5) + duplicate protection.

## 7. Billing & Activation
- init-payment idempotency behavior.
- webhook paid -> activation عبر signals (subscription/promo/verification/extras).
- webhook unknown attempt should not crash.

## 8. Files & Uploads
- size/type validation.
- max upload dynamic by feature plan.
- attachment upload across request/support/verification/promo.

## 9. Support Tickets
- create/list/detail/assign/status/comment/attachment.
- teams and priorities behavior.

## 10. Regression Suite (CI)
- smoke suite لكل release.
- integration suite لرحلات end-to-end الأساسية.
- report: pass/fail + flaky + زمن التنفيذ.
