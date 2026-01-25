from __future__ import annotations

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .checks import has_feature
from .upload_limits import user_max_upload_mb


class MyFeaturesView(APIView):
    def get(self, request):
        user = request.user
        data = {
            "verify_blue": has_feature(user, "verify_blue"),
            "verify_green": has_feature(user, "verify_green"),
            "promo_ads": has_feature(user, "promo_ads"),
            "priority_support": has_feature(user, "priority_support"),
            "max_upload_mb": user_max_upload_mb(user),
        }
        return Response(data, status=status.HTTP_200_OK)
