# Build context: Server/. Keep the toolchain aligned with local verification.
FROM swift:6.3-noble AS build
WORKDIR /build
COPY Package.swift Package.resolved ./
RUN swift package resolve --force-resolved-versions
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release --product RealPacmanServer --static-swift-stdlib \
    && mkdir /staging \
    && cp "$(swift build -c release --show-bin-path)/RealPacmanServer" /staging/ \
    && find -L "$(swift build -c release --show-bin-path)" -maxdepth 1 -name '*.resources' -exec cp -Ra {} /staging/ \;

FROM ubuntu:noble
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --user-group --create-home --home-dir /app vapor
WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging/ /app/
COPY --chown=vapor:vapor entrypoint.sh /app/entrypoint.sh
USER vapor:vapor
ENV HOST=0.0.0.0 PORT=8080 AUTO_MIGRATE=false
EXPOSE 8080
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["serve", "--env", "production"]
