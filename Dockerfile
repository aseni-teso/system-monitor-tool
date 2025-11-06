FROM alpine:latest

RUN apk add --no-cache bash coreutils bc curl netcat-openbsd tini procps coreutils python3

WORKDIR /app

COPY configs/ ./configs/
COPY helpers ./helpers/
COPY src/ ./src/
COPY README.md LICENSE ./

RUN chmod +x ./src/*.sh ./helpers/*.sh && \
    ln -s /sbin/tini /tini || true

ENV EXPORTER_PORT=9100 \
    COLLECTION_INTERVAL=0 \
    OUTPUT_FORMAT=text \
    TOP_PROCS_COUNT=5

EXPOSE 9100

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

ENTRYPOINT ["/tini", "--"]
CMD [ "./src/system_metrics.sh" ]
