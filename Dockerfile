FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/lib/sing-box /etc/sing-box/logs

RUN curl -fsSL https://sing-box.app/install.sh | sh

WORKDIR /var/lib/sing-box

EXPOSE 443

HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD sing-box version || exit 1

CMD ["/bin/bash", "-c", "sing-box -D /var/lib/sing-box -c /etc/sing-box/config.json run 2>&1 | tee -a /etc/sing-box/logs/sing_box_$(date +\"%Y%m%d\").log"]