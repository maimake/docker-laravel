FROM centos:7

RUN yum -y install --setopt=tsflags=nodocs epel-release \
&& yum -y update \
&& yum -y install --setopt=tsflags=nodocs \
# develop
autoconf \
automake \
binutils \
bison \
flex \
gcc \
gcc-c++ \
gettext \
libtool \
make \
patch \
pkgconfig \
redhat-rpm-config \
rpm-build \
rpm-sign \
file \
# tools
bash-completion \
net-tools \
telnet \
wget \
git \
vim \
tree \
unzip \
p7zip \
ruby \
curl \
&& yum clean all

# install pip
RUN curl https://bootstrap.pypa.io/get-pip.py | python
ADD pip.conf /root/.pip/pip.conf

# install nodejs
RUN curl -sL https://rpm.nodesource.com/setup_10.x | bash - \
&& rm -rf /var/lib/yum/history/*.sqlite \
&& yum -y install nodejs && yum clean all \
&& npm install -g yarn

# 设置时区
ARG TIME_ZONE=Asia/Shanghai
RUN cp /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime && echo ${TIME_ZONE} > /etc/timezone

CMD ["/bin/sh"]

LABEL mai.ruby.ver="2.0.0"\
    mai.python.ver="2.7.5"\
    mai.nodejs.ver="10.10.0"\
    mai.npm.ver="6.4.1"


# supervisor
RUN yum -y install \
supervisor \
cronie \
&& yum clean all \
&& mkdir -p /var/log/supervisor

ADD supervisord.conf /etc/supervisord.conf
ADD supervisord.d/ /etc/supervisord.d/

EXPOSE 9001

CMD ["/usr/bin/supervisord", "-n"]

LABEL mai.supervisor.conf="/etc/supervisord.conf /etc/supervisord.d/" \
    mai.supervisor.ver="3.1.4" \
    mai.cronie.conf="/etc/sysconfig/crond /var/spool/cron/root"


# nginx-phpfpm

ENV PHPVER=72
ADD rpm-gpg /etc/pki/rpm-gpg

# install phpfpm
RUN rpm --import /etc/pki/rpm-gpg/* \
&& rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm \
&& yum -y install \
php${PHPVER}w \
php${PHPVER}w-fpm \
php${PHPVER}w-mysqlnd \
php${PHPVER}w-pear \
php${PHPVER}w-intl \
php${PHPVER}w-mbstring \
php${PHPVER}w-mcrypt \
php${PHPVER}w-bcmath \
php${PHPVER}w-opcache \
php${PHPVER}w-pecl-xdebug \
php${PHPVER}w-pecl-mongodb \
php${PHPVER}w-gd \
nginx \
&& yum clean all


# install composer
RUN wget -O composer-setup.php https://install.phpcomposer.com/installer \
&& php composer-setup.php --install-dir=/usr/local/bin/ --filename=composer \
&& rm -f composer-setup.php


ADD supervisord.d/ /etc/supervisord.d/
ADD nginx.conf /etc/nginx/nginx.conf



RUN mkdir -p /etc/pki/nginx/private/ \
# example: show phpinfo
&& cp -R /usr/share/nginx/html /var/www/ \
&& echo "<?php phpinfo();" > /var/www/html/index.php \
# run php as root
&& sed -i 's/user = apache/user = root/g' /etc/php-fpm.d/www.conf \
&& sed -i 's/group = apache/group = root/g' /etc/php-fpm.d/www.conf \
# all address
&& sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /etc/php-fpm.d/www.conf \
# read system envs
&& sed -i 's/;clear_env = no/clear_env = no/g' /etc/php-fpm.d/www.conf \
# output to console
&& ln -sf /dev/stdout /var/log/nginx/access.log \
&& ln -sf /dev/stderr /var/log/nginx/error.log

ENV XDEBUG_CONFIG "remote_enable=0 remote_host=localhost remote_port=9000 idekey=PHPSTORM remote_log=/var/log/xdebug.log"
EXPOSE 80 9000

LABEL mai.nginx.ver="1.12.2" \
    mai.nginx.conf="/etc/nginx/nginx.conf /etc/nginx/conf.d/" \
    mai.nginx.default.doc="/var/www/html" \
    mai.nginx.default.port="80" \
    mai.php.ver="7.2.9" \
    mai.php.conf="/etc/php.ini /etc/php.d/" \
    mai.php.exts="mysql intl mbstring opcache xdebug" \
    mai.phpfpm.port="9000" \
    mai.phpfpm.conf="/etc/php-fpm.conf /etc/php-fpm.d/www.conf" \
    mai.composer.ver="1.6.5"


# laravel

ADD supervisord.d/ /etc/supervisord.d/
ADD nginx.conf /etc/nginx/nginx.conf

RUN crontab -l | { cat; echo "* * * * * php /var/www/artisan schedule:run >> /dev/null 2>&1"; } | crontab -

WORKDIR /var/www

LABEL mai.nginx.default.doc="/var/www/public"


