# Stage 1: builder
FROM alpine:3.22 AS builder

RUN apk add --no-cache bash coreutils
WORKDIR /src

COPY configs/ ./configs/
COPY helpers ./helpers/
COPY src/ ./src/
COPY README.md LICENSE ./

RUN chmod +x ./src/*.sh ./helpers/*.sh

# Stage 2: runtime
FROM alpine:3.22

RUN apk add --no-cache bash procps curl tini python3

RUN addgroup -S -g 1000 appgroup && adduser -S -u 1000 -G appgroup appuser

WORKDIR /app

COPY --from=builder /src/configs ./configs
COPY --from=builder /src/helpers ./helpers
COPY --from=builder /src/src ./src

RUN chmod +x ./src/*.sh ./helpers/*.sh \
    && mkdir -p /tmp /var/tmp \
    && chown -R appuser:appgroup /app /tmp /var/tmp \
    && ln -s /sbin/tini /tini || true

ENV EXPORTER_PORT=9100 \
    COLLECTION_INTERVAL=0 \
    OUTPUT_FORMAT=text \
    TOP_PROCS_COUNT=5 \
    REFRESH_INTERVAL=5

EXPOSE 9100

USER appuser

ENTRYPOINT ["/tini", "--"]
CMD [ "./src/system_metrics.sh" ]
