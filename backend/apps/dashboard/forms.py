from django import forms

from apps.providers.models import ProviderProfile, Category, SubCategory


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


class CategoryForm(forms.ModelForm):
    """نموذج إضافة/تعديل تصنيف رئيسي"""
    
    class Meta:
        model = Category
        fields = ['name', 'is_active']
        labels = {
            'name': 'اسم التصنيف',
            'is_active': 'مفعّل',
        }
        widgets = {
            'name': forms.TextInput(attrs={
                'class': 'w-full rounded-lg border-gray-200 focus:border-violet-400 focus:ring-violet-400 px-4 py-3',
                'placeholder': 'مثال: صيانة منزلية',
            }),
            'is_active': forms.CheckboxInput(attrs={
                'class': 'w-5 h-5 rounded border-gray-300 text-violet-600 focus:ring-violet-500',
            }),
        }


class SubCategoryForm(forms.ModelForm):
    """نموذج إضافة/تعديل تصنيف فرعي"""
    
    class Meta:
        model = SubCategory
        fields = ['category', 'name', 'is_active']
        labels = {
            'category': 'التصنيف الرئيسي',
            'name': 'اسم التصنيف الفرعي',
            'is_active': 'مفعّل',
        }
        widgets = {
            'category': forms.Select(attrs={
                'class': 'w-full rounded-lg border-gray-200 focus:border-violet-400 focus:ring-violet-400 px-4 py-3',
            }),
            'name': forms.TextInput(attrs={
                'class': 'w-full rounded-lg border-gray-200 focus:border-violet-400 focus:ring-violet-400 px-4 py-3',
                'placeholder': 'مثال: كهرباء',
            }),
            'is_active': forms.CheckboxInput(attrs={
                'class': 'w-5 h-5 rounded border-gray-300 text-violet-600 focus:ring-violet-500',
            }),
        }
