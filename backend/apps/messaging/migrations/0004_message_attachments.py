from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("messaging", "0003_thread_user_state"),
    ]

    operations = [
        migrations.AddField(
            model_name="message",
            name="attachment",
            field=models.FileField(blank=True, null=True, upload_to="messaging/attachments/%Y/%m/%d/"),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_name",
            field=models.CharField(blank=True, default="", max_length=255),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_type",
            field=models.CharField(blank=True, default="", max_length=20),
        ),
    ]
