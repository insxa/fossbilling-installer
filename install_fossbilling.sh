#!/bin/bash
# FossBilling 一键安装脚本 for Ubuntu
# Author: ChatGPT

set -e

echo "=== 更新系统包 ==="
apt update -y && apt upgrade -y

echo "=== 安装基础环境 ==="
apt install -y nginx mariadb-server php php-fpm php-mysql php-xml php-mbstring php-curl php-zip unzip git wget curl redis-server memcached libmemcached-tools

echo "=== 启动并设置开机自启 ==="
systemctl enable --now nginx mariadb

echo "=== 配置数据库 ==="
DB_NAME=fossbilling
DB_USER=hb_user
DB_PASS=$(openssl rand -hex 8)

mysql -uroot <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "数据库信息："
echo "DB_NAME=$DB_NAME"
echo "DB_USER=$DB_USER"
echo "DB_PASS=$DB_PASS"

echo "=== 下载 FossBilling ==="
mkdir -p /var/www/fosssbilling
cd /var/www/fossbilling
wget -O fossbilling.zip https://github.com/FOSSBilling/FOSSBilling/releases/download/0.8.7/FOSSBilling-0.8.7.zip
unzip fossbilling.zip
rm fossbilling.zip

echo "=== 设置权限 ==="
chown -R www-data:www-data /var/www/fossbilling

echo "=== 配置 Nginx ==="
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
cat >/etc/nginx/sites-available/fossbilling.conf <<EOF
server {
    listen 80;
    server_name _;

    root /var/www/fossbilling;
    index index.php index.html;

    location / {
        try_files $uri $uri/ @rewrite;
    }

    # Block access to sensitive files and return 404 to make it indistinguishable from a missing file
    location ~* .(ini|sh|inc|bak|twig|sql)$ {
        return 404;
    }

    # Block access to hidden files except for .well-known
    location ~ /\.(?!well-known\/) {
        return 404;
    }

    # Disable PHP execution in /uploads
    location ~* /uploads/.*\.php$ {
        return 404;
    }
        
    # Deny access to /data
    location ~* /data/ {
        return 404;
    }

    location @rewrite {
        rewrite ^/page/(.*)$ /index.php?_url=/custompages/$1;
        rewrite ^/(.*)$ /index.php?_url=/$1;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VER-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

ln -s /etc/nginx/sites-available/fossbilling.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

echo "=== 安装完成 ==="
echo "请访问 http://服务器IP 继续 FossBilling 安装向导"
echo "数据库信息：DB_NAME=$DB_NAME, DB_USER=$DB_USER, DB_PASS=$DB_PASS"
