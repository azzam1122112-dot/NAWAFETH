from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("messaging", "0004_message_attachments"),
    ]

    operations = [
        migrations.AddField(
            model_name="threaduserstate",
            name="favorite_label",
            field=models.CharField(
                blank=True,
                choices=[
                    ("potential_client", "عميل محتمل"),
                    ("important_conversation", "محادثة مهمة"),
                    ("incomplete_contact", "تواصل غير مكتمل"),
                ],
                default="",
                help_text="تصنيف المفضلة: عميل محتمل / محادثة مهمة / تواصل غير مكتمل",
                max_length=30,
            ),
        ),
        migrations.AddField(
            model_name="threaduserstate",
            name="client_label",
            field=models.CharField(
                blank=True,
                choices=[
                    ("potential", "عميل محتمل"),
                    ("current", "عميل حالي"),
                    ("past", "عميل سابق"),
                ],
                default="",
                help_text="تمييز العميل: محتمل / حالي / سابق",
                max_length=20,
            ),
        ),
    ]
