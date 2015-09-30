#!/bin/bash

# check environment variables
[ -z "${DB_PORT_5432_TCP_ADDR}" ] && echo "The Postgres container is not correctly linked! Add --link postgres:db to the docker run parameters!" && exit 1
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-${POSTGRESQL_ENV_POSTGRES_PASSWORD}}
POSTGRES_USER=${POSTGRES_USER:-${POSTGRESQL_ENV_POSTGRES_USER}}
POSTGRES_USER=${POSTGRES_USER:-postgres}
[ -z "${POSTGRES_PASSWORD}" ] && echo "Postgres password undefined! Add -e POSTGRES_PASSWORD=\"blabla\" to the docker run parameters!" && exit 1
[ -z "${DOMAIN}" ] && echo "Domain undefined! Add -e DOMAIN=\"ip or domain name\" to the docker run parameters!" && exit 1

DDBB="mitro"
CLASSPATH="java/server/lib/keyczar-0.71f-040513.jar:java/server/lib/gson-2.2.4.jar:java/server/lib/log4j-1.2.17.jar"
KEYS_PATH="/mitrocore_secrets/sign_keyczar"

# run tests
ant test

# check the postgres connection and the existence of the database
if [ "`PGPASSWORD="${POSTGRES_PASSWORD}" psql -h${DB_PORT_5432_TCP_ADDR} -U${POSTGRES_USER} -lqt | cut -d \| -f 1 | grep -w ${DDBB} | wc -l`" -eq "0" ]; then
        echo "Database ${DDBB} does not exist!"
        PGPASSWORD="${POSTGRES_PASSWORD}" psql -h${DB_PORT_5432_TCP_ADDR} -U${POSTGRES_USER} -c "CREATE DATABASE ${DDBB} WITH OWNER ${POSTGRES_USER} ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE='en_US.utf8'"
fi


# change the postgresql connection string to point to db link
sed -i "s|postgresql://localhost:5432/${DDBB}|postgresql://${DB_PORT_5432_TCP_ADDR}:5432/${DDBB}?user=${POSTGRES_USER}\&amp;password=${POSTGRES_PASSWORD}|" /srv/mitro/mitro-core/build.xml
# do not generate random secrets every time server starts
# https://github.com/mitro-co/mitro/issues/128#issuecomment-129950839 
sed -i "/<sysproperty key=\"generateSecretsForTest\" value=\"true\"\/>/d" /srv/mitro/mitro-core/build.xml


# generate keys at root dir
java -cp $CLASSPATH org.keyczar.KeyczarTool create --location=$KEYS_PATH --purpose=sign
java -cp $CLASSPATH org.keyczar.KeyczarTool addkey --location=$KEYS_PATH --status=primary

# generate certs
export PASSPHRASE="password"		# Main.java:474 https://github.com/mitro-co/mitro/blob/master/mitro-core/java/server/src/co/mitro/core/server/Main.java

subj="
C=SP
ST=IllesBalears
O=Habitissimo
localityName=Palma
commonName=$DOMAIN
organizationalUnitName=devops
emailAddress=developers@habitissimo.com
"

openssl genrsa -des3 -out server.key -passout env:PASSPHRASE 2048
openssl req -new -sha256 -key server.key -out server.csr -passin env:PASSPHRASE -subj "$(echo -n "$subj" | tr '\n' '/')"
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt -passin env:PASSPHRASE
openssl pkcs12 -export -inkey server.key -in server.crt -name mitro_server -out server.p12 -passin env:PASSPHRASE -passout env:PASSPHRASE
/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.85.x86_64/jre/bin/keytool -importkeystore -srckeystore server.p12 -srcstoretype pkcs12 -srcalias mitro_server -destkeystore server.jks -deststoretype jks -deststorepass password -destalias jetty -srcstorepass password

cp server.jks /srv/mitro/mitro-core/build/java/src/co/mitro/core/server/debug_keystore.jks
cp server.jks /srv/mitro/mitro-core/java/server/src/co/mitro/core/server/debug_keystore.jks

# configure the browser extensions
sed -i "s/www.mitro.co\|mitroaccess.com\|secondary.mitro.ca/${DOMAIN}/" /srv/mitro/browser-ext/login/common/config/config.release.js
sed -i "s/443/8443/" /srv/mitro/browser-ext/login/common/config/config.release.js

# exec command
cd /srv/mitro/mitro-core
exec "$@"
