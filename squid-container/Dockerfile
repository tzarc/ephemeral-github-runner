FROM b4tman/squid:latest

USER root

COPY support/entrypoint.sh /entrypoint.sh
COPY support/squid.conf /etc/squid/squid.conf

RUN chmod 0755 /entrypoint.sh \
    && chown -R squid /entrypoint.sh /etc/squid

USER squid

CMD ["sh", "-c", "/entrypoint.sh"]