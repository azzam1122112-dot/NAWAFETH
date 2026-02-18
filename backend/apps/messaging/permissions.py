from rest_framework.permissions import BasePermission

from apps.marketplace.models import ServiceRequest

from .models import Thread


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


class IsThreadParticipant(BasePermission):
    """Allows only participants of a thread (direct or request-based)."""

    def has_permission(self, request, view):
        thread_id = view.kwargs.get("thread_id")
        if not thread_id:
            return True

        thread = (
            Thread.objects.select_related("request", "request__client", "request__provider__user", "participant_1", "participant_2")
            .filter(id=thread_id)
            .first()
        )
        if not thread:
            return False

        return bool(thread.is_participant(request.user))
