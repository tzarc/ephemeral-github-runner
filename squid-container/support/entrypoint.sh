#!/bin/sh
sed -i -e "s/@@ALLOWED_DOMAINS_LIST@@/${ALLOWED_DOMAINS_LIST}/g" ${SQUID_CONFIG_FILE}
/usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -z && exec /usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -YCd 1