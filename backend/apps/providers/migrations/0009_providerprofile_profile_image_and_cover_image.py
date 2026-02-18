from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("providers", "0008_rename_providers_pr_provider_f3502a_idx_providers_p_provide_935cf6_idx"),
    ]

    operations = [
        migrations.AddField(
            model_name="providerprofile",
            name="cover_image",
            field=models.FileField(blank=True, null=True, upload_to="providers/cover/%Y/%m/"),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="profile_image",
            field=models.FileField(blank=True, null=True, upload_to="providers/profile/%Y/%m/"),
        ),
    ]
