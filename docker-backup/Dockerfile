FROM alpine:3.18

LABEL maintainer="JH <jh@localhost>"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/johann8/" \
      org.label-schema.version=$VERSION

ENV FILE_NAME=backup.tzst

RUN apk --no-cache add \
    tar \
    xz \
    zstd \
    gzip \
    bzip2 \
    bash \
    grep \
    # Remove apk cache
    && rm -rf /var/cache/apk/*

COPY rootfs/ /

VOLUME /backup
ENTRYPOINT ["/usr/local/bin/backup.sh"]
CMD ["backup"]
