from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from .models import SupportTicket, SupportStatusLog, SupportTicketStatus
from apps.notifications.services import create_notification


def change_ticket_status(*, ticket: SupportTicket, new_status: str, by_user, note: str = ""):
    """
    تغيير الحالة + تسجيل Log
    """
    if ticket.status == new_status:
        return ticket

    old = ticket.status
    ticket.status = new_status
    ticket.last_action_by = by_user

    if new_status == SupportTicketStatus.IN_PROGRESS:
        # لو أول مرة يبدأ معالجة
        if not ticket.assigned_at:
            ticket.assigned_at = timezone.now()

    if new_status == SupportTicketStatus.RETURNED:
        ticket.returned_at = timezone.now()

    if new_status == SupportTicketStatus.CLOSED:
        ticket.closed_at = timezone.now()

    ticket.save(update_fields=["status", "last_action_by", "assigned_at", "returned_at", "closed_at", "updated_at"])

    SupportStatusLog.objects.create(
        ticket=ticket,
        from_status=old,
        to_status=new_status,
        changed_by=by_user,
        note=(note or "")[:200],
    )

    # Notify ticket requester immediately when support status changes.
    status_labels = {
        SupportTicketStatus.NEW: "جديد",
        SupportTicketStatus.IN_PROGRESS: "تحت المعالجة",
        SupportTicketStatus.RETURNED: "معاد للعميل",
        SupportTicketStatus.CLOSED: "مغلق",
    }
    from_label = status_labels.get(old, old)
    to_label = status_labels.get(new_status, new_status)
    body = f"تم تحديث حالة البلاغ ({ticket.code or ticket.id}) من {from_label} إلى {to_label}."
    trimmed_note = (note or "").strip()
    if trimmed_note:
        body += f" ملاحظة: {trimmed_note}"
    body = body[:500]

    create_notification(
        user=ticket.requester,
        title="تحديث على البلاغ",
        body=body,
        kind="report_status_change",
        url=f"/support/tickets/{ticket.id}/",
        actor=by_user,
        meta={
            "ticket_id": ticket.id,
            "ticket_code": ticket.code or "",
            "from_status": old,
            "to_status": new_status,
        },
        pref_key="report_status_change",
    )
    return ticket


@transaction.atomic
def assign_ticket(*, ticket: SupportTicket, team_id, user_id, by_user, note: str = ""):
    """
    تعيين فريق/موظف + تحويل تلقائي إلى IN_PROGRESS إذا كانت NEW
    """
    # lock ticket
    ticket = SupportTicket.objects.select_for_update().get(pk=ticket.pk)

    if team_id is not None:
        ticket.assigned_team_id = team_id
    if user_id is not None:
        ticket.assigned_to_id = user_id

    ticket.last_action_by = by_user
    if not ticket.assigned_at:
        ticket.assigned_at = timezone.now()

    ticket.save(update_fields=["assigned_team", "assigned_to", "assigned_at", "last_action_by", "updated_at"])

    # لو كانت جديدة نحولها لمعالجة
    if ticket.status == SupportTicketStatus.NEW:
        change_ticket_status(ticket=ticket, new_status=SupportTicketStatus.IN_PROGRESS, by_user=by_user, note=note)

    return ticket
