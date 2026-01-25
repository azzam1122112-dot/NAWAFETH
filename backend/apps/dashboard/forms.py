from django import forms

from apps.providers.models import ProviderProfile


class AcceptAssignProviderForm(forms.Form):
    provider = forms.ModelChoiceField(
        queryset=ProviderProfile.objects.select_related("user").all(),
        required=True,
        label="المزود",
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # تحسين UX
        self.fields["provider"].widget.attrs.update(
            {
                "class": "w-full rounded-xl border border-gray-200 px-3 py-2",
            }
        )
