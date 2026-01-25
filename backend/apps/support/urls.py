from django.urls import path

from .views import (
    SupportTeamListView,
    SupportTicketCreateView,
    MySupportTicketsListView,
    SupportTicketDetailView,
    SupportTicketBackofficeListView,
    SupportTicketAssignView,
    SupportTicketStatusView,
    SupportTicketAddCommentView,
    SupportTicketAddAttachmentView,
)

urlpatterns = [
    # meta
    path("teams/", SupportTeamListView.as_view(), name="teams"),

    # client
    path("tickets/create/", SupportTicketCreateView.as_view(), name="ticket_create"),
    path("tickets/my/", MySupportTicketsListView.as_view(), name="my_tickets"),
    path("tickets/<int:pk>/", SupportTicketDetailView.as_view(), name="ticket_detail"),
    path("tickets/<int:pk>/comments/", SupportTicketAddCommentView.as_view(), name="ticket_add_comment"),
    path("tickets/<int:pk>/attachments/", SupportTicketAddAttachmentView.as_view(), name="ticket_add_attachment"),

    # backoffice list
    path("backoffice/tickets/", SupportTicketBackofficeListView.as_view(), name="backoffice_tickets"),

    # backoffice actions
    path("backoffice/tickets/<int:pk>/assign/", SupportTicketAssignView.as_view(), name="ticket_assign"),
    path("backoffice/tickets/<int:pk>/status/", SupportTicketStatusView.as_view(), name="ticket_status"),
]
