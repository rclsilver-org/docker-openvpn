FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    easy-rsa \
    gettext \
    iptables \
    ip6tables \
    openvpn \
    supervisor \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin/easyrsa

COPY rootfs /docker-entrypoint.d
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

RUN chmod +x /docker-entrypoint.sh /healthcheck.sh

EXPOSE 1194/udp

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
