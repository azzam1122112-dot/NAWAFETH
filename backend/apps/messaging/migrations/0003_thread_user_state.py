from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ("messaging", "0002_thread_is_direct_thread_participant_1_and_more"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="ThreadUserState",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_favorite", models.BooleanField(default=False)),
                ("is_archived", models.BooleanField(default=False)),
                ("is_blocked", models.BooleanField(default=False)),
                ("blocked_at", models.DateTimeField(blank=True, null=True)),
                ("archived_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "thread",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="user_states", to="messaging.thread"),
                ),
                (
                    "user",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="thread_states", to=settings.AUTH_USER_MODEL),
                ),
            ],
            options={
                "indexes": [
                    models.Index(fields=["user", "is_favorite"], name="messaging_t_user_id_439020_idx"),
                    models.Index(fields=["user", "is_archived"], name="messaging_t_user_id_a56866_idx"),
                    models.Index(fields=["user", "is_blocked"], name="messaging_t_user_id_b28302_idx"),
                ],
                "unique_together": {("thread", "user")},
            },
        ),
    ]
