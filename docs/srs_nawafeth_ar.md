# SRS مختصرة - منصة نوافذ (Execution-Ready)

## 1. الهدف
منصة سوق خدمات تربط العميل بمقدم الخدمة عبر البحث والتصفح وطلب العروض والخدمة العاجلة والمحادثات والتنبيهات والتقييمات.

## 2. الأدوار والصلاحيات
- `visitor`: تصفح عام فقط.
- `phone_only`: محادثة + إعجاب + متابعة + نافذتي.
- `client`: كل ما سبق + إنشاء طلب + تقييم + تعليق + إعدادات التنبيهات.
- `provider`: إدارة الملف المهني + استقبال الطلبات + العروض + التنفيذ + الاشتراكات/التوثيق/الترويج.
- `staff`: صلاحيات تشغيل ولوحات backoffice حسب `access_profile`.

## 3. قواعد الإتاحة (Gating)
- أي عملية فوق مستوى الزائر تتطلب JWT صالح.
- العمليات الحساسة تعتمد الحد الأدنى من الدور (`IsAtLeastPhoneOnly/Client/Provider`).
- اكتمال الملف شرط لتحويل `phone_only` إلى `client`.
- إنشاء ملف مزود يحوّل الدور إلى `provider`.

## 4. النطاق الوظيفي الأساسي
- Accounts: OTP + JWT + profile + completion.
- Providers: قائمة/تفاصيل/خدمات/بورتفوليو/متابعة/إعجاب.
- Marketplace: طلبات (normal/competitive/urgent) + عروض + دورة تنفيذ.
- Messaging: Thread + Messages + Read + WebSocket.
- Notifications: list/unread/mark-read/device-token.
- Reviews: تقييم متعدد محاور بعد اكتمال الطلب.
- Billing: فواتير + init payment + webhook.
- Verification/Promo/Subscriptions/Extras: رحلة طلب -> فاتورة -> تفعيل عبر signals.
- Support/Backoffice/Analytics: تذاكر + صلاحيات + مؤشرات وتشغيل.

## 5. المتطلبات غير الوظيفية
- أمان: OTP throttling + JWT refresh + تحقق صارم للصلاحيات.
- أداء: فهرسة البحث + ضغط/تخزين وسائط + pagination.
- اعتمادية: health endpoints + audit/events + idempotency بالدفع.
- قابلية تشغيل: تقارير إدارية وتتبّع أحداث.

## 6. الفجوة الحالية (Backend vs Flutter)
- الباكند مكتمل وظيفيًا لمعظم الوحدات الأساسية.
- Flutter موصول جيدًا في auth/providers/marketplace/notifications/reviews.
- غير مكتمل في messaging realtime + billing + verification + subscriptions + promo + extras.

## 7. تعريف النجاح
- إتمام رحلة عميل كاملة: OTP -> completion -> request -> offer/accept -> chat -> complete -> review.
- إتمام رحلة مزود كاملة: registration -> inbox -> accept/start/complete.
- إتمام رحلة مالية كاملة: invoice -> init-payment -> webhook paid -> feature activation.
