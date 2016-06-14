FROM ubuntu:14.04
MAINTAINER Kevin Meng <magicbuaa@gmail.com>

# set some environment variables
ENV APP_NAME app
ENV APP_EMAIL app@laravel.com
ENV APP_DOMAIN app.dev

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

ENV DB_USER homestead
ENV DB_PASS secret
ENV DB homestead

# upgrade the container
RUN apt-get update && \
    apt-get upgrade -y

# install some prerequisites
RUN apt-get install -y curl build-essential python2.7-dev python-pip \
    gcc git libmcrypt4 libpcre3-dev libcurl4-openssl-dev memcached make \
    vim wget debconf-utils

# set the locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale  && \
    locale-gen en_US.UTF-8  && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# install nginx
RUN apt-get install -y --force-yes nginx-extras
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default && \
    rm -rf /etc/nginx/sites-enabled/default && \
    ln -fs "/etc/nginx/sites-available/homestead" "/etc/nginx/sites-enabled/homestead" && \
    mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html/
VOLUME ["/var/www/html/app"]
VOLUME ["/var/cache/nginx"]
VOLUME ["/var/log/nginx"]

# install php
RUN sudo apt-get -y --force-yes install php5-dev php-pear php5-fpm

# install mysql 
RUN echo mysql-server mysql-server/root_password password $DB_PASS | debconf-set-selections;\
    echo mysql-server mysql-server/root_password_again password $DB_PASS | debconf-set-selections;\
    apt-get install -y mysql-server-5.6 && \
    echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf && \
    sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
RUN /usr/sbin/mysqld & \
    sleep 10s && \
    echo "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY '$DB_PASS' WITH GRANT OPTION; CREATE USER '$DB_USER'@'0.0.0.0' IDENTIFIED BY '$DB_PASS'; GRANT ALL ON *.* TO '$DB_USER'@'0.0.0.0' IDENTIFIED BY '$DB_PASS' WITH GRANT OPTION; GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE DATABASE $DB;" | mysql -uroot -p$DB_PASS
VOLUME ["/var/lib/mysql"]

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc

#install laravel installer
RUN composer global require "laravel/installer"

# install redis 
RUN apt-get install -y redis-server

# install mongodb
ADD mongodb.sh /home/
RUN chmod +x /home/mongodb.sh
RUN sudo /home/mongodb.sh true 3.0

# install supervisor
RUN apt-get install -y supervisor && \
    mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
VOLUME ["/var/log/supervisor"]

# expose ports
EXPOSE 80 443 3306 6379 27017

# set container entrypoints
ENTRYPOINT ["/bin/bash","-c"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
