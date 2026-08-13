FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wireguard-tools iproute2 iptables net-tools && rm -rf /var/lib/apt/lists/*
COPY bin/wstunnel-linux-amd64 /usr/local/bin/wstunnel
RUN chmod +x /usr/local/bin/wstunnel && wstunnel --version
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 51820/udp
ENTRYPOINT ["/entrypoint.sh"]
