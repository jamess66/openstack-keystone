FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \ 
    # update apt packages
    gcc \
    # c complier
    python3-dev \
    # python dev headers
    libmariadb-dev \
    # MariaDB/MySQL dev headers
    default-mysql-client \
    # MySQL client
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
    # clean up apt cache to reduce image size

COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install uwsgi pymysql python-memcached python-openstackclient

COPY . /app/keystone-source
RUN pip install -e /app/keystone-source

RUN mkdir -p /etc/keystone && \
    ln -s /app/keystone-source/etc/keystone.conf /etc/keystone/keystone.conf && \
    chmod +x /app/keystone-source/docker/scripts/bootstrap.sh

EXPOSE 5000

CMD ["/app/keystone-source/docker/scripts/bootstrap.sh"]
