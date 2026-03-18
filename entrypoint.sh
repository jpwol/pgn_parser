#!/usr/bin/env bash
BUFFER_POOL=${INNODB_BUFFER_POOL:-1G}
echo "[mysqld]" > /etc/mysql/conf.d/innodb.cnf
echo "innodb_buffer_pool_size=$BUFFER_POOL" >> /etc/mysql/conf.d/innodb.cnf

service mariadb start

./run_pipeline.sh

mariadb --table chess < ./tests/question1.sql
mariadb --table chess < ./tests/question2.sql
mariadb --table chess < ./tests/question3.sql
mariadb --table chess < ./tests/question4.sql
