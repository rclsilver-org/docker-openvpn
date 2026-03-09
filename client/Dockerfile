FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    ca-certificates \
    openvpn \
    iproute2 \
    iputils \
    curl \
    && rm -rf /var/cache/apk/*

# Script de healthcheck pour le client
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

ENTRYPOINT ["openvpn"]
CMD ["--config", "/etc/openvpn/openvpn.conf"]
