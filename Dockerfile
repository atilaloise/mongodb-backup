FROM alpine:3.9
MAINTAINER Atila Aloise de Almeida
RUN apk add --update  bash python3 mongodb-tools samba-client shadow && \
    rm -rf /var/cache/apk/* && \
    touch /etc/samba/smb.conf && \
    pip3 install awscli pymongo
RUN mkdir -p /var/cache/samba && chmod 0755 /var/cache/samba
COPY functions.sh /
COPY entrypoint /entrypoint
COPY mongoparser.py /usr/local/bin/mongoparser
ENTRYPOINT ["/entrypoint"]