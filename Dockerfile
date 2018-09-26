FROM centos:7

RUN sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

# ADD CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
ADD CentOS7-Base-ustc.repo /etc/yum.repos.d/CentOS-Base.repo
ADD rpm-gpg /etc/pki/rpm-gpg

RUN rpm --import /etc/pki/rpm-gpg/* \
&& yum -y install --setopt=tsflags=nodocs epel-release \
&& sed -e 's!^mirrorlist=!#mirrorlist=!g' \
         -e 's!^#baseurl=!baseurl=!g' \
         -e 's!//download\.fedoraproject\.org/pub!//mirrors.ustc.edu.cn!g' \
         -e 's!http://mirrors\.ustc!https://mirrors.ustc!g' \
         -i /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo \
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

# ruby gem mirror
RUN gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/ \
&& gem install bundler \
&& bundle config mirror.https://rubygems.org https://gems.ruby-china.org


# install pip
RUN curl https://bootstrap.pypa.io/get-pip.py | python \
&& mkdir -p ~/.pip \
&& echo $'[global] \n\
trusted-host = mirrors.aliyun.com \n\
index-url = http://mirrors.aliyun.com/pypi/simple/' \
> ~/.pip/pip.conf


# install nodejs
RUN curl -sL https://rpm.nodesource.com/setup_10.x | bash - \
&& rm -rf /var/lib/yum/history/*.sqlite \
&& yum -y install nodejs && yum clean all \
&& echo $'registry = https://registry.npm.taobao.org/ \n\
sass_binary_site = https://npm.taobao.org/mirrors/node-sass/' \
> ~/.npmrc \
&& npm install -g cnpm yarn


# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

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
php${PHPVER}w-mysql \
php${PHPVER}w-pear \
php${PHPVER}w-intl \
php${PHPVER}w-mbstring \
php${PHPVER}w-mcrypt \
php${PHPVER}w-bcmath \
php${PHPVER}w-opcache \
php${PHPVER}w-pecl-xdebug \
php${PHPVER}w-gd \
nginx \
&& yum clean all


# install composer (先科学上网)
RUN wget -O composer-setup.php https://install.phpcomposer.com/installer \
&& php composer-setup.php --install-dir=bin --filename=composer \
&& rm -f composer-setup.php \
&& composer config -g repo.packagist composer https://packagist.phpcomposer.com


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

WORKDIR /var/www/html
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


