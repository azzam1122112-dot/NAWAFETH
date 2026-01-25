from rest_framework.permissions import BasePermission

from apps.marketplace.models import ServiceRequest


class IsRequestParticipant(BasePermission):
    """
    يسمح فقط لمالك الطلب أو المزوّد المعيّن على الطلب
    """

    def has_permission(self, request, view):
        request_id = view.kwargs.get("request_id")
        if not request_id:
            return True  # لبعض الـ views التي تستخدم thread_id لاحقًا

        sr = (
            ServiceRequest.objects.filter(id=request_id)
            .select_related("client", "provider__user")
            .first()
        )
        if not sr:
            return False

        if sr.client_id == request.user.id:
            return True

        # provider__user هو صاحب حساب مقدم الخدمة
        if sr.provider and sr.provider.user_id == request.user.id:
            return True

        return False
