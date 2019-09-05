FROM amazonlinux:2

# File Author / Maintainer
MAINTAINER ljay

# update amazon software repo
RUN yum -y update && yum -y install shadow-utils procps \
    && amazon-linux-extras install -y php7.2

RUN set -ex; \
    \
    yum install -y openssl unzip zlib-devel git; \
    yum install -y php-pecl-mcrypt php-gd php-gmp \
    php-intl php-mbstring php-opcache php-pear php-pecl-igbinary \
    php-pecl-redis php-soap php-xmlrpc \
    ;

# Set UTC timezone
#RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo UTC > /etc/timezone
RUN printf '[PHP]\ndate.timezone = "%s"\n', UTC > /etc/php.d/tzone.ini \
    && "date"

RUN set -eux; \
    [ ! -d /var/www/html ]; \
    mkdir -p /var/www/html; \
    # allow running as an arbitrary user
    groupadd -g 500 www-data; \
    useradd -d /var/www/html -s /sbin/nologin -u 500 -g 500 www-data; \
    chown -R www-data:www-data /var/www/html; \
    chmod 0775 /var/www/html

# update pecl channel definitions https://github.com/docker-library/php/issues/443
RUN set -eux; \
    \
    pecl update-channels; \
    # smoke test
    php --version

COPY docker-php-entrypoint /usr/local/bin/

ENTRYPOINT ["docker-php-entrypoint"]

WORKDIR /var/www/html

RUN set -eux; \
    chmod +x /usr/local/bin/docker-php-entrypoint; \
    cd /etc; \
    { \
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
    } | tee php-fpm.d/docker.conf; \
    { \
        echo '[global]'; \
        echo 'daemonize = no'; \
        echo; \
        echo '[www]'; \
        echo 'listen = 9000'; \
    } | tee php-fpm.d/zz-docker.conf

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]
