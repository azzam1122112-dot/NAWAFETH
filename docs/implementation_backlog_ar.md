# Backlog تنفيذي (Phased)

## Phase 1 - ربط Flutter مع عقود API الحالية
- توحيد DTOs واستقبال الأخطاء لكل modules.
- إكمال Messaging module (REST + WS).
- ربط Billing/Subscriptions/Verification/Promo/Extras.
- إزالة الشاشات/البيانات الـ mock واستبدالها بمصادر حقيقية.

## Phase 2 - سياسات وصلاحيات
- Gate موحد في Flutter حسب `role_state` و`completion`.
- منع الوصول للشاشات الحساسة عند نقص الصلاحية.
- توحيد account switching مع refresh بيانات المستخدم.

## Phase 3 - جودة وتشغيل
- إضافة integration tests لرحلات المستخدم الحرجة.
- تحسين observability (errors + latency + business events).
- تحسين الأداء للوسائط والبحث.

## Phase 4 - إدارة وعمليات
- استكمال لوحة التشغيل للدعم.
- استكمال لوحات backoffice (dashboards/access/analytics exports).
- إغلاق دورة التذاكر والرموز المرجعية.

## أولويات فورية (Now)
1. Messaging realtime end-to-end.
2. Subscription/Invoice payment end-to-end.
3. Verification + Promo flows end-to-end.
4. Dynamic upload limits from `/api/features/my/` بدل القيم الثابتة في التطبيق.
