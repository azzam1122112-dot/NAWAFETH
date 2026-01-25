from django.urls import path

from .api import MyFeaturesView

urlpatterns = [
    path("my/", MyFeaturesView.as_view(), name="my_features"),
]
