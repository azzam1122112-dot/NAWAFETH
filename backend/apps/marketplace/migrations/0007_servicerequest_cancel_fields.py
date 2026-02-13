from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("marketplace", "0006_servicerequest_completion_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="servicerequest",
            name="cancel_reason",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="canceled_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
