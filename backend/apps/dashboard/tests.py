import pytest

from apps.accounts.models import User
from apps.dashboard.views import _compute_actions
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
