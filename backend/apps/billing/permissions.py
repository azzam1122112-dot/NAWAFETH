from __future__ import annotations

from rest_framework.permissions import BasePermission


class IsInvoiceOwner(BasePermission):
    message = "غير مصرح لك بالوصول لهذه الفاتورة."

    def has_object_permission(self, request, view, obj):
        return obj.user_id == request.user.id
