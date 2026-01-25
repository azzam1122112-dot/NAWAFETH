from django.core.exceptions import ValidationError


MAX_FILE_SIZE_MB = 100
MAX_FILE_SIZE = MAX_FILE_SIZE_MB * 1024 * 1024


def validate_file_size(file_obj):
    if file_obj.size > MAX_FILE_SIZE:
        raise ValidationError(f"الملف كبير جدًا. الحد الأقصى {MAX_FILE_SIZE_MB}MB")
