from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("providers", "0005_providerprofile_updated_at_and_portfolio"),
    ]

    operations = [
        migrations.CreateModel(
            name="ProviderService",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=150)),
                ("description", models.TextField(blank=True, default="", max_length=1000)),
                ("price_from", models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ("price_to", models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                (
                    "price_unit",
                    models.CharField(
                        choices=[
                            ("fixed", "سعر ثابت"),
                            ("starting_from", "يبدأ من"),
                            ("hour", "بالساعة"),
                            ("day", "باليوم"),
                            ("negotiable", "قابل للتفاوض"),
                        ],
                        default="fixed",
                        max_length=20,
                    ),
                ),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "provider",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="services",
                        to="providers.providerprofile",
                    ),
                ),
                (
                    "subcategory",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name="provider_services",
                        to="providers.subcategory",
                    ),
                ),
            ],
            options={
                "indexes": [
                    models.Index(fields=["provider", "is_active", "updated_at"], name="providers_pr_provider_f3502a_idx"),
                ],
            },
        ),
    ]
