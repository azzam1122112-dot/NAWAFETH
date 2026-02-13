from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("providers", "0006_providerservice"),
    ]

    operations = [
        migrations.AddField(
            model_name="providerprofile",
            name="about_details",
            field=models.TextField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="content_sections",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="experiences",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="languages",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="qualifications",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="seo_keywords",
            field=models.CharField(blank=True, default="", max_length=500),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="seo_meta_description",
            field=models.CharField(blank=True, default="", max_length=500),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="seo_slug",
            field=models.CharField(blank=True, default="", max_length=150),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="social_links",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="providerprofile",
            name="website",
            field=models.URLField(blank=True, default=""),
        ),
    ]
