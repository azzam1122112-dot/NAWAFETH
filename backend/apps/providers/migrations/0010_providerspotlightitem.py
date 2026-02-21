from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("providers", "0009_providerprofile_profile_image_and_cover_image"),
    ]

    operations = [
        migrations.CreateModel(
            name="ProviderSpotlightItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("file_type", models.CharField(choices=[("image", "صورة"), ("video", "فيديو")], max_length=20)),
                ("file", models.FileField(upload_to="providers/spotlights/%Y/%m/")),
                ("caption", models.CharField(blank=True, default="", max_length=200)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "provider",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="spotlight_items",
                        to="providers.providerprofile",
                    ),
                ),
            ],
        ),
    ]
