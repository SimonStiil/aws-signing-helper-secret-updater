FROM alpine:3.22.0 AS base
WORKDIR /app
ARG USER=user
RUN apk add --no-cache bash libc6-compat && \
    adduser -D $USER

FROM base AS builder
RUN apk add --no-cache make git go && \
    git clone https://github.com/aws/rolesanywhere-credential-helper.git && \
    sh -c 'cd rolesanywhere-credential-helper && make release' && \
    git clone https://github.com/SimonStiil/go-file-secret-sync.git && \
    sh -c 'cd go-file-secret-sync && CGO_ENABLED=1 go build .'
FROM base
WORKDIR /usr/local/bin
COPY --from=builder /app/rolesanywhere-credential-helper/build/bin/aws_signing_helper /usr/local/bin/aws_signing_helper
COPY --from=builder /app/go-file-secret-sync/go-file-secret-sync /usr/local/bin/go-file-secret-sync
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
USER $USER
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
