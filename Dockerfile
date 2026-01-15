FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \ 
    gcc \
    python3-dev \
    libmariadb-dev \
    default-mysql-client \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install uwsgi pymysql python-memcached python-openstackclient

COPY . /app/keystone-source
RUN pip install -e /app/keystone-source

RUN mkdir -p /etc/keystone && \
    ln -s /app/keystone-source/etc/keystone.conf /etc/keystone/keystone.conf && \
    chmod +x /app/keystone-source/docker/scripts/bootstrap.sh

EXPOSE 5000

CMD ["uwsgi", "--http", "0.0.0.0:5000", "--wsgi-file", "/app/keystone-source/keystone/server/wsgi.py", "--callable", "application"]
