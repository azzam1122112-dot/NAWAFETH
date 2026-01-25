from django.urls import path
from .views import DashboardsListView, MyAccessView

urlpatterns = [
    path("dashboards/", DashboardsListView.as_view(), name="dashboards"),
    path("me/access/", MyAccessView.as_view(), name="my_access"),
]
