from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("unified_requests", "0002_rename_unified_requ_request_bcc4e6_idx_unified_req_request_c49539_idx_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="unifiedrequest",
            name="request_type",
            field=models.CharField(
                choices=[
                    ("helpdesk", "دعم ومساعدة (HD)"),
                    ("promo", "إعلانات وترويج (MD)"),
                    ("verification", "توثيق (AD)"),
                    ("subscription", "ترقية واشتراكات (SD)"),
                    ("extras", "خدمات إضافية (P)"),
                    ("reviews", "مراجعات وتقييمات (RV)"),
                ],
                max_length=20,
            ),
        ),
    ]
