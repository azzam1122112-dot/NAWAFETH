from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("marketplace", "0004_servicerequestattachment"),
    ]

    operations = [
        migrations.AddField(
            model_name="servicerequest",
            name="estimated_service_amount",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="expected_delivery_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="provider_inputs_approved",
            field=models.BooleanField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="provider_inputs_decided_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="provider_inputs_decision_note",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="received_amount",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="remaining_amount",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True),
        ),
    ]
