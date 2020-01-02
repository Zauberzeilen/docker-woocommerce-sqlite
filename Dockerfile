FROM ubuntu:16.04
MAINTAINER Björn Rennfanz <bjoern@zauberzeilen.de>

# Environment for NGINX
ENV NGINX_HOST=localhost \
    NGINX_PORT=80 \
    DOLLAR=$

# Set to system to en_US.UTF-8 locale
ENV OS_LOCALE="en_US.UTF-8" \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE}

# Basic Requirements
RUN apt-get update && apt-get install -y pwgen python-setuptools curl git unzip sqlite3 gettext-base sqlite3

# Install php7-fpm
RUN BUILD_DEPS='software-properties-common' \
    && dpkg-reconfigure locales \
    # Install common libraries
    && apt-get install --no-install-recommends -y $BUILD_DEPS \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    # Install PHP libraries
    # php7.3-mcrypt not support and move to PECL. Use extension Sodium: http://php.net/manual/book.sodium.php
    && apt-get install -y curl php7.3-fpm php7.3-cli php7.3-sqlite3 php7.3-mysql php7.3-curl php7.3-gd php7.3-intl php-pear php7.3-imagick php7.3-imap php7.3-memcache php7.3-ps php7.3-pspell php7.3-recode php7.3-tidy php7.3-xmlrpc php7.3-xsl \
    # Install composer
    && curl -sS https://getcomposer.org/installer | php -- --version=1.8.4 --install-dir=/usr/local/bin --filename=composer \
    # Cleaning
    && apt-get purge -y --auto-remove $BUILD_DEPS \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# php7-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.3/fpm/php.ini \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.3/fpm/php.ini \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.3/fpm/php.ini \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.3/fpm/php-fpm.conf \
    && sed -i -e "s/pid\s*=\s*\/run\/php\/php7.3-fpm.pid/pid = \/var\/run\/php7.3-fpm.pid/g" /etc/php/7.3/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.3/fpm/pool.d/www.conf \
    && sed -i -e "s/listen\s*=\s*\/run\/php\/php7.3-fpm.sock/listen = \/var\/run\/php7.3-fpm.sock/g" /etc/php/7.3/fpm/pool.d/www.conf \
    && find /etc/php/7.3/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Install nginx
RUN apt-get update && apt-get install -y nginx

# nginx config
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf \
    && sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf \
    && echo "daemon off;" >> /etc/nginx/nginx.conf

# nginx site conf
ADD ./config/nginx-site.conf /etc/nginx/conf.d/mysite.template

# Supervisor Config
RUN /usr/bin/easy_install supervisor \
    && /usr/bin/easy_install supervisor-stdout
ADD ./config/supervisord.conf /etc/supervisord.conf

# Add startup script
ADD ./scripts/start.sh /start.sh
RUN chmod 755 /start.sh

# expose web server
EXPOSE 80

# volume for woocommerce install
VOLUME ["/usr/share/nginx/www"]

CMD ["/bin/bash", "/start.sh"]
