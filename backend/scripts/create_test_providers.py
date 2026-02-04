"""
سكريبت لإنشاء مزودي خدمة تجريبيين لاختبار التطبيق
"""
from apps.accounts.models import User, UserRole
from apps.providers.models import ProviderProfile, SubCategory, ProviderCategory
from decimal import Decimal

# المدن السعودية
SAUDI_CITIES = [
    'الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 'الدمام',
    'الخبر', 'الظهران', 'الطائف', 'تبوك', 'بريدة',
]

# بيانات مزودي خدمة تجريبيين
TEST_PROVIDERS = [
    {
        'phone': '0501111111',
        'username': '@provider1',
        'full_name': 'أحمد محمد',
        'display_name': 'أحمد - خدمات السباكة',
        'bio': 'خبرة 10 سنوات في أعمال السباكة والصيانة',
        'city': 'الرياض',
        'years_experience': 10,
        'provider_type': 'individual',
        'lat': Decimal('24.7136'),
        'lng': Decimal('46.6753'),
        'accepts_urgent': True,
    },
    {
        'phone': '0502222222',
        'username': '@provider2',
        'full_name': 'فهد العتيبي',
        'display_name': 'فهد - خدمات الكهرباء',
        'bio': 'كهربائي محترف - جميع أنواع الأعمال الكهربائية',
        'city': 'جدة',
        'years_experience': 8,
        'provider_type': 'individual',
        'lat': Decimal('21.4858'),
        'lng': Decimal('39.1925'),
        'accepts_urgent': True,
    },
    {
        'phone': '0503333333',
        'username': '@provider3',
        'full_name': 'شركة التميز للصيانة',
        'display_name': 'شركة التميز',
        'bio': 'شركة متخصصة في جميع أعمال الصيانة والتشطيبات',
        'city': 'الدمام',
        'years_experience': 15,
        'provider_type': 'company',
        'lat': Decimal('26.4207'),
        'lng': Decimal('50.0888'),
        'accepts_urgent': True,
    },
    {
        'phone': '0504444444',
        'username': '@provider4',
        'full_name': 'خالد السعيد',
        'display_name': 'خالد - نجارة وديكور',
        'bio': 'نجار ماهر - أثاث مخصص وديكورات خشبية',
        'city': 'الرياض',
        'years_experience': 12,
        'provider_type': 'individual',
        'lat': Decimal('24.7742'),
        'lng': Decimal('46.7386'),
        'accepts_urgent': False,
    },
    {
        'phone': '0505555555',
        'username': '@provider5',
        'full_name': 'مؤسسة البناء الحديث',
        'display_name': 'البناء الحديث',
        'bio': 'مؤسسة متخصصة في أعمال البناء والتشطيبات',
        'city': 'جدة',
        'years_experience': 20,
        'provider_type': 'company',
        'lat': Decimal('21.5433'),
        'lng': Decimal('39.1728'),
        'accepts_urgent': True,
    },
]

def create_test_providers():
    """إنشاء مزودي خدمة تجريبيين"""
    
    # الحصول على التصنيف الفرعي "عام"
    try:
        general_subcategory = SubCategory.objects.get(name='عام')
    except SubCategory.DoesNotExist:
        print('⚠️  التصنيف الفرعي "عام" غير موجود')
        return
    
    created_count = 0
    for data in TEST_PROVIDERS:
        # التحقق من وجود المستخدم
        if User.objects.filter(phone=data['phone']).exists():
            print(f'⏭️  المستخدم {data["phone"]} موجود بالفعل')
            continue
        
        # إنشاء المستخدم
        user = User.objects.create_user(
            phone=data['phone'],
            username=data['username'],
            full_name=data['full_name'],
            is_phone_verified=True,
            city=data['city'],
        )
        
        # تعيين دور مزود خدمة
        UserRole.objects.create(
            user=user,
            role='provider',
        )
        
        # إنشاء ملف مزود الخدمة
        provider = ProviderProfile.objects.create(
            user=user,
            provider_type=data['provider_type'],
            display_name=data['display_name'],
            bio=data['bio'],
            city=data['city'],
            years_experience=data['years_experience'],
            lat=data['lat'],
            lng=data['lng'],
            accepts_urgent=data['accepts_urgent'],
        )
        
        # ربط التصنيف الفرعي
        ProviderCategory.objects.create(
            provider=provider,
            subcategory=general_subcategory,
        )
        
        created_count += 1
        print(f'✅ تم إنشاء: {data["display_name"]} في {data["city"]}')
    
    print(f'\n🎉 تم إنشاء {created_count} مزود خدمة جديد!')
    print(f'📊 إجمالي المزودين الآن: {ProviderProfile.objects.count()}')

if __name__ == '__main__':
    create_test_providers()
