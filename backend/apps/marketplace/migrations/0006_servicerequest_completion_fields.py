from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("marketplace", "0005_servicerequest_execution_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="servicerequest",
            name="actual_service_amount",
            field=models.DecimalField(
                blank=True, decimal_places=2, max_digits=12, null=True
            ),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="delivered_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
