#!/usr/bin/env bash
####################
set -e
####################
LND_COMMIT="42b856dbb98dee83d284646bfc3eab96199cec62"
####################
build() {
	mkdir -p /build
	cd /build
	git clone https://github.com/lightningnetwork/lnd
	cd lnd
	git checkout ${LND_COMMIT}
	go mod tidy
	make
	make install
	mkdir -p /lnd
	mv ${GOPATH}/bin/* /lnd/
	rm -r ${GOPATH}
	mkdir -p ${GOPATH}
	cd
	rm -r /build
}
####################
build
