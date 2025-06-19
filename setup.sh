#!/usr/bin/env sh
PROJECT_NAME="${1:-django-app}"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME
touch README.md
poetry init --name $PROJECT_NAME --python "3.13.5" --no-interaction
poetry add django==5.2.3 python-dotenv drf-spectacular django-prometheus django-redis
poetry run django-admin startproject config .

# Create .env file
cat > .env << 'EOF'
SECRET_KEY=your-secret-key-here-change-in-production
DEBUG=true
ALLOWED_HOSTS=*
REDIS_URL=redis://redis:6379/1
EOF

poetry run python manage.py startapp core

# Update settings.py
cat > config/settings.py << 'EOF'
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY')
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '').split(',')

INSTALLED_APPS = [
    'django_prometheus',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'drf_spectacular',
    'core',
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django_prometheus.middleware.PrometheusAfterMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://redis:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {'retry_on_timeout': True},
        }
    }
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/app/logs/django.log',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['file'],
        'level': 'INFO',
    },
}

REST_FRAMEWORK = {
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'Django API',
    'VERSION': '1.0.0',
}
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.13-slim

WORKDIR /app
RUN mkdir -p /app/logs

RUN pip install poetry
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.create false && poetry install --only=main

COPY . .
RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF

# Create prometheus.yml
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'django'
    static_configs:
      - targets: ['web:8000']
  
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  redis:
    image: redis:8.0-alpine
    ports:
      - "6379:6379"
      
  redis-exporter:
    image: oliver006/redis_exporter
    ports:
      - "9121:9121"
    environment:
      - REDIS_ADDR=redis://redis:6379
    depends_on:
      - redis
      
  web:
    build: .
    ports:
      - "8000:8000"
    env_file:
      - .env
    depends_on:
      - redis
    volumes:
      - .:/app
      - ./logs:/app/logs
      
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-data:/var/lib/grafana
EOF

# Add cache test to core app
cat > core/views.py << 'EOF'
from django.http import JsonResponse
from django.core.cache import cache
import time

def test_cache(request):
    key = 'test_timestamp'
    cached_value = cache.get(key)
    
    if cached_value is None:
        timestamp = int(time.time())
        cache.set(key, timestamp, 30)
        return JsonResponse({'timestamp': timestamp, 'cached': False})
    else:
        return JsonResponse({'timestamp': cached_value, 'cached': True})
EOF

# Update URLs
cat > config/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('django_prometheus.urls')),
    path('schema/', SpectacularAPIView.as_view(), name='schema'),
    path('swagger/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger'),
    path('', include('core.urls')),
]
EOF

cat > core/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path('test-cache/', views.test_cache, name='test_cache'),
]
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
*.manifest
*.spec
pip-log.txt
pip-delete-this-directory.txt
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/
*.mo
*.pot
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal
instance/
.webassets-cache
.scrapy
docs/_build/
.pybuilder/
target/
.ipynb_checkpoints
profile_default/
ipython_config.py
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/
.spyderproject
.spyproject
.ropeproject
/site
.mypy_cache/
.dmypy.json
dmypy.json
.pyre/
.pytype/
cython_debug/
.ruff_cache/
logs/
grafana-data/
EOF

echo "Setup complete! Run: docker compose up --build"
