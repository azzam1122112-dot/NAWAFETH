from django.urls import path

from .views import PlansListView, MySubscriptionsView, SubscribeView

urlpatterns = [
    path("plans/", PlansListView.as_view(), name="plans"),
    path("my/", MySubscriptionsView.as_view(), name="my_subscriptions"),
    path("subscribe/<int:plan_id>/", SubscribeView.as_view(), name="subscribe"),
]
