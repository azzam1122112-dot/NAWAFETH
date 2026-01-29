from django.urls import path
from .views import (
    ThrottledTokenObtainPairView,
    ThrottledTokenRefreshView,
    complete_registration,
    me_view,
    otp_send,
    otp_verify,
    wallet_view,
)

app_name = "accounts"

urlpatterns = [
    path("otp/send/", otp_send, name="otp_send"),
    path("otp/verify/", otp_verify, name="otp_verify"),
    path("complete/", complete_registration, name="complete"),
    path("wallet/", wallet_view, name="wallet"),
    path("token/", ThrottledTokenObtainPairView.as_view(), name="token"),
    path("token/refresh/", ThrottledTokenRefreshView.as_view(), name="token_refresh"),
    path("me/", me_view, name="me"),
]
