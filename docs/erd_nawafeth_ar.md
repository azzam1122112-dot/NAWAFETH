# ERD عملي - Nawafeth

## 1. الهوية والحساب
- `accounts_user`
- `accounts_otp`
- `accounts_wallet`

## 2. المزودون والتصنيفات
- `providers_category`
- `providers_subcategory`
- `providers_providerprofile` -> FK user
- `providers_providercategory` -> FK provider + subcategory
- `providers_providerservice` -> FK provider + subcategory
- `providers_providerportfolioitem` -> FK provider
- `providers_providerfollow` -> FK user + provider
- `providers_providerlike` -> FK user + provider
- `providers_providerportfoliolike` -> FK user + item

## 3. السوق والطلبات
- `marketplace_servicerequest` -> FK client + provider? + subcategory
- `marketplace_offer` -> FK request + provider
- `marketplace_requeststatuslog` -> FK request + actor?
- `marketplace_servicerequestattachment` -> FK request

## 4. المراسلة
- `messaging_thread` -> O2O request
- `messaging_message` -> FK thread + sender
- `messaging_messageread` -> FK message + user

## 5. الإشعارات
- `notifications_notification` -> FK user
- `notifications_eventlog`
- `notifications_devicetoken` -> FK user

## 6. التقييم
- `reviews_review` -> O2O request + FK provider + client

## 7. الفوترة والدفع
- `billing_invoice` -> FK user
- `billing_paymentattempt` -> FK invoice
- `billing_webhookevent`

## 8. التوثيق والترويج والاشتراكات والإضافات
- `verification_verificationrequest` -> FK requester + invoice?
- `verification_verificationdocument` -> FK request
- `verification_verifiedbadge` -> FK user + request
- `promo_promorequest` -> FK requester + invoice?
- `promo_promoasset` -> FK request
- `subscriptions_subscriptionplan`
- `subscriptions_subscription` -> FK user + plan + invoice?
- `extras_extrapurchase` -> FK user + invoice?

## 9. الدعم والإدارة
- `support_supportteam`
- `support_supportticket` -> FK requester + assigned_team? + assigned_to?
- `support_supportattachment` -> FK ticket
- `support_supportcomment` -> FK ticket
- `support_supportstatuslog` -> FK ticket
- `backoffice_dashboard`
- `backoffice_useraccessprofile` -> O2O user

## 10. علاقات حرجة
- Request <-> Thread: علاقة 1:1.
- Request <-> Offer: علاقة 1:N.
- Invoice -> Activation: تُحوّل حالات verification/promo/subscription/extras عبر signals.
