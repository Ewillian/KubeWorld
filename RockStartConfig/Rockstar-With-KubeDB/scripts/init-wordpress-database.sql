CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER 'wordpress'@'%' IDENTIFIED BY 'wordpress';
USE wordpress;
ALTER USER 'wordpress'@'%' identified with mysql_native_password by 'wordpress';
