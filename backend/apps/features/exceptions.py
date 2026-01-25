from rest_framework.exceptions import PermissionDenied


class FeatureLocked(PermissionDenied):
    default_detail = "هذه الميزة غير متاحة في باقتك الحالية."
    default_code = "feature_locked"
