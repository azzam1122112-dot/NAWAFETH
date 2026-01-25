from django.urls import path

from .views import ExtrasCatalogView, MyExtrasListView, BuyExtraView

urlpatterns = [
    path("catalog/", ExtrasCatalogView.as_view(), name="catalog"),
    path("my/", MyExtrasListView.as_view(), name="my_extras"),
    path("buy/<str:sku>/", BuyExtraView.as_view(), name="buy_extra"),
]
