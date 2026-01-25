from django.core.exceptions import ValidationError

MAX_FILE_SIZE_MB = 100
MAX_FILE_SIZE = MAX_FILE_SIZE_MB * 1024 * 1024

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".mp4", ".pdf"}


def validate_file_size(file_obj):
    if file_obj.size > MAX_FILE_SIZE:
        raise ValidationError(f"الملف كبير جدًا. الحد الأقصى {MAX_FILE_SIZE_MB}MB")


def validate_extension(file_obj):
    name = (getattr(file_obj, "name", "") or "").lower()
    ext = "." + name.split(".")[-1] if "." in name else ""
    if ext and ext not in ALLOWED_EXT:
        raise ValidationError("امتداد الملف غير مسموح. المسموح: jpg, png, mp4, pdf")
