from django.core.exceptions import ValidationError


def validate_user_file_size(file_obj, max_mb: int):
    size_limit = max_mb * 1024 * 1024
    if file_obj.size > size_limit:
        raise ValidationError(f"الملف كبير جدًا. الحد الأقصى {max_mb}MB")
