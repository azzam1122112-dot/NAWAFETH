import pytest
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import User
from apps.backoffice.models import AccessLevel, Dashboard, UserAccessProfile
from apps.audit.models import AuditAction, AuditLog
from apps.dashboard.views import _compute_actions, _dashboard_allowed
from apps.dashboard.templatetags.dashboard_access import can_access
from apps.marketplace.models import RequestStatus, ServiceRequest
from apps.providers.models import Category, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_compute_actions_provider_unassigned_can_accept_when_sent(django_assert_num_queries):
	cat = Category.objects.create(name="تصميم", is_active=True)
	sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

	client_user = User.objects.create_user(phone="0500000201")
	provider_user = User.objects.create_user(phone="0500000202")

	ProviderProfile.objects.create(
		user=provider_user,
		provider_type="individual",
		display_name="مزود",
		bio="bio",
		city="الرياض",
		years_experience=0,
	)

	sr = ServiceRequest.objects.create(
		client=client_user,
		subcategory=sub,
		title="طلب",
		description="وصف",
		request_type="competitive",
		status=RequestStatus.SENT,
		city="الرياض",
	)

	# 1 query only: ProviderProfile.exists() for the special-case accept.
	with django_assert_num_queries(1):
		actions = _compute_actions(provider_user, sr)

	assert actions["can_accept"] is True


@pytest.mark.django_db
def test_compute_actions_staff_does_not_query_providerprofile_when_sent(django_assert_num_queries):
	cat = Category.objects.create(name="تصميم", is_active=True)
	sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

	client_user = User.objects.create_user(phone="0500000203")
	staff_user = User.objects.create_user(phone="0500000204", is_staff=True)

	sr = ServiceRequest.objects.create(
		client=client_user,
		subcategory=sub,
		title="طلب",
		description="وصف",
		request_type="competitive",
		status=RequestStatus.SENT,
		city="الرياض",
	)

	# No ProviderProfile lookup for staff
	with django_assert_num_queries(0):
		actions = _compute_actions(staff_user, sr)

	assert actions["can_accept"] is True
	assert actions["can_cancel"] is True


@pytest.mark.django_db
def test_dashboard_allowed_write_uses_content_dashboard_code():
	staff_user = User.objects.create_user(
		phone="0500000205",
		password="Pass12345!",
		is_staff=True,
	)
	content_dashboard = Dashboard.objects.create(
		code="content",
		name_ar="إدارة المحتوى",
		sort_order=20,
	)
	ap = UserAccessProfile.objects.create(
		user=staff_user,
		level=AccessLevel.USER,
	)
	ap.allowed_dashboards.set([content_dashboard])

	assert _dashboard_allowed(staff_user, "content", write=True) is True


@pytest.mark.django_db
def test_dashboard_allowed_qa_denies_write_even_with_content_access():
	staff_user = User.objects.create_user(
		phone="0500000206",
		password="Pass12345!",
		is_staff=True,
	)
	content_dashboard = Dashboard.objects.create(
		code="content",
		name_ar="إدارة المحتوى",
		sort_order=20,
	)
	ap = UserAccessProfile.objects.create(
		user=staff_user,
		level=AccessLevel.QA,
	)
	ap.allowed_dashboards.set([content_dashboard])

	assert _dashboard_allowed(staff_user, "content", write=False) is True
	assert _dashboard_allowed(staff_user, "content", write=True) is False


@pytest.mark.django_db
def test_dashboard_allowed_staff_without_access_profile_is_denied():
	staff_user = User.objects.create_user(
		phone="0500000207",
		password="Pass12345!",
		is_staff=True,
	)
	assert _dashboard_allowed(staff_user, "content", write=False) is False
	assert can_access(staff_user, "content", write=False) is False


@pytest.mark.django_db
def test_access_profile_update_action_updates_level_dashboards_and_expiry():
	admin_user = User.objects.create_user(
		phone="0500000208",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	content_dashboard = Dashboard.objects.create(code="content", name_ar="إدارة المحتوى", sort_order=20)
	support_dashboard = Dashboard.objects.create(code="support", name_ar="الدعم", sort_order=30)
	UserAccessProfile.objects.create(user=admin_user, level=AccessLevel.ADMIN)

	target_user = User.objects.create_user(phone="0500000209", password="Pass12345!", is_staff=True)
	target_ap = UserAccessProfile.objects.create(user=target_user, level=AccessLevel.USER)
	target_ap.allowed_dashboards.set([content_dashboard])

	c = Client()
	assert c.login(phone="0500000208", password="Pass12345!")
	url = reverse("dashboard:access_profile_update_action", args=[target_ap.id])
	res = c.post(
		url,
		data={
			"level": AccessLevel.QA,
			"expires_at": "2030-01-01T10:30",
			"dashboard_ids": [str(support_dashboard.id)],
		},
	)
	assert res.status_code == 302

	target_ap.refresh_from_db()
	assert target_ap.level == AccessLevel.QA
	assert target_ap.expires_at is not None
	assert list(target_ap.allowed_dashboards.values_list("code", flat=True)) == ["support"]

	log = AuditLog.objects.filter(
		action=AuditAction.ACCESS_PROFILE_UPDATED,
		reference_type="backoffice.user_access_profile",
		reference_id=str(target_ap.id),
	).first()
	assert log is not None
	assert log.actor_id == admin_user.id
	assert log.extra.get("target_user_id") == target_user.id
	assert log.extra.get("before", {}).get("level") == AccessLevel.USER
	assert log.extra.get("after", {}).get("level") == AccessLevel.QA


@pytest.mark.django_db
def test_access_profile_toggle_revoke_action_blocks_self_and_allows_others():
	admin_user = User.objects.create_user(
		phone="0500000210",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	UserAccessProfile.objects.create(user=admin_user, level=AccessLevel.ADMIN).allowed_dashboards.set([access_dashboard])

	target_user = User.objects.create_user(phone="0500000211", password="Pass12345!", is_staff=True)
	target_ap = UserAccessProfile.objects.create(user=target_user, level=AccessLevel.USER)

	c = Client()
	assert c.login(phone="0500000210", password="Pass12345!")

	# revoke other user
	url_other = reverse("dashboard:access_profile_toggle_revoke_action", args=[target_ap.id])
	res_other = c.post(url_other, data={})
	assert res_other.status_code == 302
	target_ap.refresh_from_db()
	assert target_ap.revoked_at is not None
	log_revoke = AuditLog.objects.filter(
		action=AuditAction.ACCESS_PROFILE_REVOKED,
		reference_type="backoffice.user_access_profile",
		reference_id=str(target_ap.id),
	).first()
	assert log_revoke is not None
	assert log_revoke.actor_id == admin_user.id

	# cannot revoke self
	self_ap = admin_user.access_profile
	url_self = reverse("dashboard:access_profile_toggle_revoke_action", args=[self_ap.id])
	res_self = c.post(url_self, data={})
	assert res_self.status_code == 302
	self_ap.refresh_from_db()
	assert self_ap.revoked_at is None

	# un-revoke other user
	res_unrevoke = c.post(url_other, data={})
	assert res_unrevoke.status_code == 302
	target_ap.refresh_from_db()
	assert target_ap.revoked_at is None
	log_unrevoke = AuditLog.objects.filter(
		action=AuditAction.ACCESS_PROFILE_UNREVOKED,
		reference_type="backoffice.user_access_profile",
		reference_id=str(target_ap.id),
	).first()
	assert log_unrevoke is not None
	assert log_unrevoke.actor_id == admin_user.id


@pytest.mark.django_db
def test_access_profile_create_action_creates_profile_and_audit():
	admin_user = User.objects.create_user(
		phone="0500000212",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	content_dashboard = Dashboard.objects.create(code="content", name_ar="إدارة المحتوى", sort_order=20)
	UserAccessProfile.objects.create(user=admin_user, level=AccessLevel.ADMIN).allowed_dashboards.set([access_dashboard])

	target_user = User.objects.create_user(phone="0500000213", password="Pass12345!", is_staff=True)
	assert not hasattr(target_user, "access_profile")

	c = Client()
	assert c.login(phone="0500000212", password="Pass12345!")
	url = reverse("dashboard:access_profile_create_action")
	res = c.post(
		url,
		data={
			"target_phone": target_user.phone,
			"level": AccessLevel.USER,
			"expires_at": "2031-01-01T11:00",
			"dashboard_ids": [str(content_dashboard.id)],
		},
	)
	assert res.status_code == 302

	target_ap = UserAccessProfile.objects.get(user=target_user)
	assert target_ap.level == AccessLevel.USER
	assert list(target_ap.allowed_dashboards.values_list("code", flat=True)) == ["content"]

	log = AuditLog.objects.filter(
		action=AuditAction.ACCESS_PROFILE_CREATED,
		reference_type="backoffice.user_access_profile",
		reference_id=str(target_ap.id),
	).first()
	assert log is not None
	assert log.actor_id == admin_user.id
	assert log.extra.get("created") is True


@pytest.mark.django_db
def test_access_profile_create_action_updates_existing_profile():
	admin_user = User.objects.create_user(
		phone="0500000214",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	content_dashboard = Dashboard.objects.create(code="content", name_ar="إدارة المحتوى", sort_order=20)
	support_dashboard = Dashboard.objects.create(code="support", name_ar="الدعم", sort_order=30)
	UserAccessProfile.objects.create(user=admin_user, level=AccessLevel.ADMIN).allowed_dashboards.set([access_dashboard])

	target_user = User.objects.create_user(phone="0500000215", password="Pass12345!", is_staff=True)
	target_ap = UserAccessProfile.objects.create(user=target_user, level=AccessLevel.QA)
	target_ap.allowed_dashboards.set([support_dashboard])

	c = Client()
	assert c.login(phone="0500000214", password="Pass12345!")
	url = reverse("dashboard:access_profile_create_action")
	res = c.post(
		url,
		data={
			"target_phone": target_user.phone,
			"level": AccessLevel.POWER,
			"dashboard_ids": [str(content_dashboard.id)],
		},
	)
	assert res.status_code == 302

	target_ap.refresh_from_db()
	assert target_ap.level == AccessLevel.POWER
	assert list(target_ap.allowed_dashboards.values_list("code", flat=True)) == ["content"]

	log = AuditLog.objects.filter(
		action=AuditAction.ACCESS_PROFILE_UPDATED,
		reference_type="backoffice.user_access_profile",
		reference_id=str(target_ap.id),
	).first()
	assert log is not None
	assert log.actor_id == admin_user.id
	assert log.extra.get("created") is False


@pytest.mark.django_db
def test_guard_prevents_demoting_last_active_admin():
	admin_user = User.objects.create_user(
		phone="0500000216",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	content_dashboard = Dashboard.objects.create(code="content", name_ar="إدارة المحتوى", sort_order=20)
	admin_ap = UserAccessProfile.objects.create(user=admin_user, level=AccessLevel.ADMIN)
	admin_ap.allowed_dashboards.set([access_dashboard, content_dashboard])

	c = Client()
	assert c.login(phone="0500000216", password="Pass12345!")
	url = reverse("dashboard:access_profile_update_action", args=[admin_ap.id])
	res = c.post(
		url,
		data={
			"level": AccessLevel.USER,
			"dashboard_ids": [str(content_dashboard.id)],
		},
	)
	assert res.status_code == 302
	admin_ap.refresh_from_db()
	assert admin_ap.level == AccessLevel.ADMIN


@pytest.mark.django_db
def test_guard_prevents_revoking_last_active_admin():
	operator_user = User.objects.create_user(
		phone="0500000217",
		password="Pass12345!",
		is_staff=True,
	)
	access_dashboard = Dashboard.objects.create(code="access", name_ar="صلاحيات التشغيل", sort_order=10)
	operator_ap = UserAccessProfile.objects.create(user=operator_user, level=AccessLevel.USER)
	operator_ap.allowed_dashboards.set([access_dashboard])

	sole_admin_user = User.objects.create_user(phone="0500000218", password="Pass12345!", is_staff=True)
	sole_admin_ap = UserAccessProfile.objects.create(
		user=sole_admin_user,
		level=AccessLevel.ADMIN,
	)

	c = Client()
	assert c.login(phone="0500000217", password="Pass12345!")
	url = reverse("dashboard:access_profile_toggle_revoke_action", args=[sole_admin_ap.id])
	res = c.post(url, data={})
	assert res.status_code == 302
	sole_admin_ap.refresh_from_db()
	assert sole_admin_ap.revoked_at is None

	# With another active admin present, revoke should be allowed.
	second_admin_user = User.objects.create_user(phone="0500000219", password="Pass12345!", is_staff=True)
	UserAccessProfile.objects.create(user=second_admin_user, level=AccessLevel.ADMIN)
	res2 = c.post(url, data={})
	assert res2.status_code == 302
	sole_admin_ap.refresh_from_db()
	assert sole_admin_ap.revoked_at is not None
