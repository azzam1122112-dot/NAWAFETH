from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("marketplace", "0008_alter_servicerequest_request_type_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="servicerequest",
            name="status",
            field=models.CharField(
                choices=[
                    ("new", "جديد"),
                    ("in_progress", "تحت التنفيذ"),
                    ("completed", "مكتمل"),
                    ("cancelled", "ملغي"),
                ],
                default="new",
                max_length=20,
            ),
        ),
        migrations.AlterField(
            model_name="servicerequest",
            name="title",
            field=models.CharField(max_length=50),
        ),
        migrations.AlterField(
            model_name="servicerequest",
            name="description",
            field=models.TextField(max_length=500),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="quote_deadline",
            field=models.DateField(blank=True, null=True),
        ),
    ]
