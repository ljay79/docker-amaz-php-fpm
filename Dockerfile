FROM amazonlinux:2018.03

# File Author / Maintainer
MAINTAINER ljay

# update amazon software repo
RUN yum -y update && yum -y install shadow-utils

RUN set -ex; \
    \
    yum install -y openssl unzip zlib-devel git; \
    yum install -y php56-cli php56-common php56-fpm php56-gd php56-gmp php56-intl \
        php56-mbstring php56-mcrypt php56-mysqlnd php56-opcache php56-pdo php-pear \
        php56-pecl-igbinary php56-pecl-jsonc php56-pecl-redis php56-process \
        php56-soap php56-xml php56-xmlrpc \
    ;

# Set UTC timezone
RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo UTC > /etc/timezone
RUN printf '[PHP]\ndate.timezone = "%s"\n', UTC > /etc/php.d/tzone.ini \
    && "date"

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer --version \
    && chmod a+x /usr/local/bin/composer

# docker container usually wont add that file which is required by some init scripts
RUN echo "" >> /etc/sysconfig/network

# cleanup
RUN yum clean all && rm -rf /tmp/* /var/tmp/*

# amazon creates php-fpm as user/group apache
# For compatibility and consistency with nginx, we rename it to nginx and change UID/GID to 1000/1000
# Usually nginx user exists as well, so we do conditionally either create nginx or change apach to nginx
RUN set -x \
    && if id -u "nginx" > /dev/null; then \
      find / -user apache -exec chown nginx {} \; >> /dev/null 2>&1 || true ; \
      find / -group apache -exec chgrp nginx {} \; >> /dev/null 2>&1 || true ; \
      usermod -d /var/www nginx ; \
    else \
      usermod -d /var/www -c nginx -l nginx apache ; \
      groupmod -n nginx apache ; \
      usermod -u 1000 nginx ; \
      groupmod -g 1000 nginx ; \
    fi \
    && chown nginx /var/run/php-fpm

RUN set -ex \
    && cd /etc \
    && mv php-fpm.d/www.conf php-fpm.d/www.conf.default \
    && sed 's! apache! nginx!g' php-fpm.d/www.conf.default >> php-fpm.d/www.conf \
    && { \
        echo '[global]'; \
        echo 'error_log = /proc/self/fd/2'; \
        echo; \
        echo '[www]'; \
        echo '; if we send this to /proc/self/fd/1, it never appears'; \
        echo 'access.log = /proc/self/fd/2'; \
        echo; \
        echo 'clear_env = no'; \
        echo; \
        echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
        echo 'catch_workers_output = yes'; \
    } | tee php-fpm.d/docker.conf \
    && { \
        echo '[global]'; \
        echo 'daemonize = no'; \
        echo; \
        echo '[www]'; \
        echo 'listen = 9000'; \
    } | tee php-fpm.d/zz-docker.conf

WORKDIR /var/www/html

CMD ["php-fpm", "-F"]
