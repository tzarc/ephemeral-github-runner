#!/bin/sh
sed -i \
    -e "s/@@ALLOWED_DOMAINS_LIST@@/${ALLOWED_DOMAINS_LIST}/g" \
    -e "s/@@MEM_CACHE_SIZE@@/${MEM_CACHE_SIZE:-256}/g" \
    -e "s/@@FILE_CACHE_SIZE@@/${FILE_CACHE_SIZE:-1024}/g" \
    -e "s/@@FILE_MAX_SIZE@@/${FILE_MAX_SIZE:-100}/g" \
    ${SQUID_CONFIG_FILE}
/usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -z && exec /usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -YCd 1