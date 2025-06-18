#!/usr/bin/env sh

PROJECT_NAME="{$1:-django-app}"

mkdir $PROJECT_NAME
cd $PROJECT_NAME
touch README.md

poetry init --name $PROJECT_NAME --python "3.13.5" --no-interaction
poetry add django==5.2.3 redis python-dotenv drf-spectacular
poetry run django-admin startproject config .

# Create .env file
cat > .env << 'EOF'
SECRET_KEY=your-secret-key-here-change-in-production
DEBUG=true
ALLOWED_HOSTS=*
REDIS_URL=redis://redis:6379/1
EOF

# Create the base project
poetry run django-admin startproject config .
poetry run python manage.py startapp core

# Update settings.py for Redis cache
cat > config/settings.py << 'EOF'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-key-change-in-production')
DEBUG = os.environ.get('DEBUG', 'True').lower() == 'true'
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'core',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
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

DATABASES = {}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://redis:6379/1'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.13-slim

WORKDIR /app

RUN pip install poetry
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.create false && poetry install --no-dev

COPY . .
RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  redis:
    image: redis:8.0-alpine
    ports:
      - "6379:6379"

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

urlpatterns = [
    path('admin/', admin.site.urls),
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

# GIT setup
cat > .gitignore << 'EOF'
# Byte-compiled / optimized / compressed files
__pycache__/
*.pyc
*.pyd
*.pyo
*.egg-info/
.pytest_cache/
.mypy_cache/

# Distributions and builds
dist/
build/
*.egg
*.whl

# Virtual environment
venv/
env/
.venv/

# IDE specific files
.idea/  # IntelliJ IDEA / PyCharm
*.iml
*.ipr
*.iws
.vscode/ # VS Code
.vscode-server/ # VS Code remote development
*.sublime-project # Sublime Text
*.sublime-workspace
.komodotools/ # Komodo IDE
.komodoproject

# Operating System Files
.DS_Store
Thumbs.db
ehthumbs.db
Desktop.ini

# Python specific files/directories
# Django specific:
db.sqlite3
/media/  # User-uploaded media files
/static_collected/ # Collected static files (if using collectstatic)
*.log
local_settings.py  # Local environment settings (critical for security)
.env # If using python-dotenv for environment variables

# Editor Backup files
*~
*.bak
*.swp
*.swo

# Test/Coverage files
.coverage
htmlcov/

# Jupyter Notebook files
.ipynb_checkpoints/
*.ipynb

# Node.js (if using a frontend framework with Django)
node_modules/
npm-debug.log
yarn-error.log

# Docker (if using Docker for development/deployment)
.dockerignore
docker-compose.override.yml # Override specific settings for local dev
*.env # Docker Compose env files

# Misc
.cache/
EOF

cat > .gitattributes << 'EOF'
# Set default line endings for text files to LF (Unix-style)
* text=auto

# Explicitly set line endings for Python files to LF
*.py text eol=lf

# Mark common image/binary files as binary to prevent diffs
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.pdf binary
*.zip binary
*.tar binary
*.gz binary
# Depending on if you want to diff logs
*.log binary 
EOF

echo "Setup complete! Run: docker compose up --build"
