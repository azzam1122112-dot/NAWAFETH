# Code Evidence Snippets

## 1) Webhook بدون Auth + عدم التحقق من التوقيع

`backend/apps/billing/views.py`
```python
class WebhookReceiverView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request, provider: str):
        signature = request.headers.get("X-Signature", "")
        event_id = request.headers.get("X-Event-Id", "")
        result = handle_webhook(provider=provider, payload=payload, signature=signature, event_id=event_id)
```

`backend/apps/billing/services.py`
```python
WebhookEvent.objects.create(
    provider=provider,
    event_id=(event_id or "")[:120],
    signature=(signature or "")[:200],
    payload=payload or {},
)
```

## 2) مصدر max_upload_mb
`backend/apps/features/api.py`
```python
data = {
  "verify_blue": has_feature(user, "verify_blue"),
  "verify_green": has_feature(user, "verify_green"),
  "promo_ads": has_feature(user, "promo_ads"),
  "priority_support": has_feature(user, "priority_support"),
  "max_upload_mb": user_max_upload_mb(user),
}
```

## 3) صلاحيات marketplace actions
`backend/apps/marketplace/views.py`
```python
class ServiceRequestCreateView(generics.CreateAPIView):
    permission_classes = [IsAtLeastClient]

class ProviderAssignedRequestAcceptView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

class RequestCancelView(APIView):
    permission_classes = [permissions.IsAuthenticated]
```

## 4) صلاحيات messaging participants-only
`backend/apps/messaging/views.py`
```python
class SendMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRequestParticipant]
```

`backend/apps/messaging/permissions.py`
```python
class IsRequestParticipant(BasePermission):
    # only request.client or request.provider.user
```

## 5) Activation flows عبر signals
`backend/apps/subscriptions/signals.py`
```python
@receiver(post_save, sender=Invoice)
def activate_subscription_on_paid(...):
    if instance.status != "paid":
        return
```

`backend/apps/verification/signals.py`
```python
@receiver(post_save, sender=Invoice)
def activate_verification_on_invoice_paid(...):
    if instance.reference_type != "verify_request":
        return
```

`backend/apps/promo/signals.py` و `backend/apps/extras/signals.py` بنفس النمط.
