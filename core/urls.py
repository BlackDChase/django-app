from django.urls import path
from . import views
from drf_spectacular.views import SpectacularSwaggerView # SpectacularRedocView

urlpatterns = [
    path('test-cache', views.test_cache, name='test_cache'),
    path('/swagger', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger'),
]
