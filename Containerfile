FROM localhost/bookworm-golang:latest

ARG DEBIAN_FRONTEND=noninteractive

COPY volume/scripts/build.sh /scripts/build.sh

RUN \
	set -e; \
	apt update; \
	apt install -y --no-install-recommends \
		wget git ca-certificates gcc libc-dev make protobuf-compiler; \
	/scripts/build.sh

ENV PATH=/lnd:${PATH}

FROM docker.io/library/debian:bookworm-slim

ENV PATH=/lnd:${PATH}

COPY --from=0 /lnd /lnd

ENTRYPOINT ["lnd"]
