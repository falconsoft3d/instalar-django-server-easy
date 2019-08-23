#!/bin/bash
echo "==1== INICIANDO === "
sudo ln -svf /usr/bin/python3 /usr/bin/python

echo "==2== Actualizando el Sistema === "
sudo apt-get -qq update
sudo apt-get -qq upgrade

echo "==3== Instalamos las dependencia para usar PostgreSQL con Python/Django: === "
sudo apt-get -qq install build-essential libpq-dev python-dev

echo "==4== Instalamos PostgreSQL Server: === "
sudo apt-get -qq install postgresql postgresql-contrib

echo "==5== Instalamos Nginx: === "
sudo apt-get -qq install nginx

echo "==6== Instalamos Supervisor: === "
sudo apt-get -qq install supervisor

echo "==7== Iniciamos Supervisor: === "
sudo systemctl enable supervisor
sudo systemctl start supervisor

echo "==8== Instalamos python-virtualenv: === "
sudo apt-get -qq install python-virtualenv

echo "==9== Configuramos PostgreSQL: === "
sudo su - postgres -c "createuser -s django"
sudo su - postgres -c "createdb django_prod --owner django"
sudo -u postgres psql -c "ALTER USER django WITH PASSWORD 'django'"

# Creamos el usuario del sistema
sudo adduser --system --quiet --shell=/bin/bash --home=/home/django --gecos 'django' --group django
gpasswd -a django sudo

echo "==10== Creamos el entorno virtual === "
virtualenv /home/django/.venv --python=python3
source /home/django/.venv/bin/activate

echo "==11== Creamos el entorno virtual === "
pip install -q Django

echo "==12== Clonamos el proyecto === "
read -p 'Indique la dirección del repo a clonar (https://github.com/falconsoft3d/django-father): ' gitrepo
git -C /home/django clone $gitrepo
read -p 'Indique la el nombre de la carpeta del proyecto (django-father): ' project
read -p 'Indique el nombre de la app principal de Django (father): ' djapp

echo "==13== Instalamos las dependencias === "
pip install -q -r /home/django/$project/requirements.txt

echo "==14== Instalamos Gunicorn === "
pip install -q gunicorn

touch /home/django/.venv/bin/gunicorn_start
chmod u+x /home/django/.venv/bin/gunicorn_start
echo '#!/bin/bash' >> /home/django/.venv/bin/gunicorn_start
echo '' >> /home/django/.venv/bin/gunicorn_start
echo 'NAME="django_app"' >> /home/django/.venv/bin/gunicorn_start
echo 'DIR=/home/django/'$project >> /home/django/.venv/bin/gunicorn_start
echo 'USER=django' >> /home/django/.venv/bin/gunicorn_start
echo 'GROUP=django' >> /home/django/.venv/bin/gunicorn_start
echo 'WORKERS=3' >> /home/django/.venv/bin/gunicorn_start
echo 'BIND=unix:/home/django/gunicorn.sock' >> /home/django/.venv/bin/gunicorn_start
echo 'DJANGO_SETTINGS_MODULE='$djapp'.settings' >> /home/django/.venv/bin/gunicorn_start
echo 'DJANGO_WSGI_MODULE='$djapp'.wsgi' >> /home/django/.venv/bin/gunicorn_start
echo 'LOG_LEVEL=error' >> /home/django/.venv/bin/gunicorn_start
echo '' >> /home/django/.venv/bin/gunicorn_start
echo 'source /home/django/.venv/bin/activate' >> /home/django/.venv/bin/gunicorn_start
echo '' >> /home/django/.venv/bin/gunicorn_start
echo 'export DJANGO_SETTINGS_MODULE=$DJANGO_SETTINGS_MODULE' >> /home/django/.venv/bin/gunicorn_start
echo 'export PYTHONPATH=$DIR:$PYTHONPATH' >> /home/django/.venv/bin/gunicorn_start
echo '' >> /home/django/.venv/bin/gunicorn_start
echo 'exec /home/django/.venv/bin/gunicorn ${DJANGO_WSGI_MODULE}:application \' >> /home/django/.venv/bin/gunicorn_start
echo '  --name $NAME \' >> /home/django/.venv/bin/gunicorn_start
echo '  --workers $WORKERS \' >> /home/django/.venv/bin/gunicorn_start
echo '  --user=$USER \' >> /home/django/.venv/bin/gunicorn_start
echo '  --group=$GROUP \' >> /home/django/.venv/bin/gunicorn_start
echo '  --bind=$BIND \' >> /home/django/.venv/bin/gunicorn_start
echo '  --log-level=$LOG_LEVEL \' >> /home/django/.venv/bin/gunicorn_start
echo '  --log-file=-' >> /home/django/.venv/bin/gunicorn_start

echo "==15== Convertimos a Ejecutable el Fichero: gunicorn_start === "
chmod u+x /home/django/.venv/bin/gunicorn_start

echo "==16== Configurando Supervisor === "
mkdir /home/django/logs
touch /home/django/logs/gunicorn-error.log
touch /etc/supervisor/conf.d/django_app.conf
echo '[program:django_app]' >> /etc/supervisor/conf.d/django_app.conf
echo 'command=/home/django/.venv/bin/gunicorn_start' >> /etc/supervisor/conf.d/django_app.conf
echo 'user=django' >> /etc/supervisor/conf.d/django_app.conf
echo 'autostart=true' >> /etc/supervisor/conf.d/django_app.conf
echo 'autorestart=true' >> /etc/supervisor/conf.d/django_app.conf
echo 'redirect_stderr=true' >> /etc/supervisor/conf.d/django_app.conf
echo 'stdout_logfile=/home/django/logs/gunicorn-error.log' >> /etc/supervisor/conf.d/django_app.conf
sudo supervisorctl reread
sudo supervisorctl update

echo "==17== Configurando Nginx ==="
touch /etc/nginx/sites-available/django_app
echo 'upstream django_app {' >> /etc/nginx/sites-available/django_app
echo '    server unix:/home/django/gunicorn.sock fail_timeout=0;' >> /etc/nginx/sites-available/django_app
echo '}' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo 'server {' >> /etc/nginx/sites-available/django_app
echo '    listen 80;' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    # add here the ip address of your server' >> /etc/nginx/sites-available/django_app
echo '    # or a domain pointing to that ip (like example.com or www.example.com)' >> /etc/nginx/sites-available/django_app
read -p 'Indique la IP del servidor: ' serverip
echo '    server_name '$serverip';' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    keepalive_timeout 5;' >> /etc/nginx/sites-available/django_app
echo '    client_max_body_size 4G;' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    access_log /home/django/logs/nginx-access.log;' >> /etc/nginx/sites-available/django_app
echo '    error_log /home/django/logs/nginx-error.log;' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    location /static/ {' >> /etc/nginx/sites-available/django_app
echo '        alias /home/django/static/;' >> /etc/nginx/sites-available/django_app
echo '    }' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    # checks for static file, if not found proxy to app' >> /etc/nginx/sites-available/django_app
echo '    location / {' >> /etc/nginx/sites-available/django_app
echo '        try_files $uri @proxy_to_app;' >> /etc/nginx/sites-available/django_app
echo '    }' >> /etc/nginx/sites-available/django_app
echo '' >> /etc/nginx/sites-available/django_app
echo '    location @proxy_to_app {' >> /etc/nginx/sites-available/django_app
echo '      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/sites-available/django_app
echo '      proxy_set_header Host $http_host;' >> /etc/nginx/sites-available/django_app
echo '      proxy_redirect off;' >> /etc/nginx/sites-available/django_app
echo '      proxy_pass http://django_app;' >> /etc/nginx/sites-available/django_app
echo '    }' >> /etc/nginx/sites-available/django_app
echo '}' >> /etc/nginx/sites-available/django_app
# Le metemos la IP al settings al final
echo 'from .settings import ALLOWED_HOSTS' >> /home/django/$project/$djapp/localsettings.py
echo 'ALLOWED_HOSTS += ["'$serverip'"]' >> /home/django/$project/$djapp/localsettings.py
echo 'STATIC_ROOT = "/home/django/static/"' >> /home/django/$project/$djapp/localsettings.py

sudo ln -s /etc/nginx/sites-available/django_app /etc/nginx/sites-enabled/django_app
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx restart

echo "=== Finalizando ==="
python /home/django/$project/manage.py migrate
python /home/django/$project/manage.py collectstatic
sudo chown django:django /home/django/* -R
sudo chown django:django /home/django/.venv/* -R
sudo chown django:django /home/django/.venv -R
sudo supervisorctl restart django_app
