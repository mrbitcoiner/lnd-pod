#!/usr/bin/env bash
####################
set -e
####################
readonly RELDIR="$(dirname ${0})"
readonly HELP_MSG="usage: <build | up | down | clean | lncli | mk-systemd | rm-systemd | help>"
readonly IMG_NAME="lnd"
readonly CT_NAME="lnd"
####################
eprintln() {
	! [ -z "${1}" ] || eprintln 'eprintln: undefined message'
	printf "${1}\n" 1>&2
	return 1
}
check_env() {
	[ -e "${RELDIR}/.env" ] || eprintln 'please, copy .env.example to .env'
	source "${RELDIR}"/.env
	[ -e "${RELDIR}/lnd.conf" ] || eprintln 'please, copy lnd.conf.example to lnd.conf'
	! [ -z "${EXT_PORT}" ] || eprintln 'undefined env EXT_PORT'
}
common() {
	mkdir -p "${RELDIR}/volume/data/lnd"
	chmod +x "${RELDIR}"/volume/scripts/*.sh
	check_env
	[ -e "${RELDIR}/volume/data/lnd/walletpass.txt" ] ||
		dd if=/dev/urandom bs=32 count=1 2>/dev/null | sha256sum | awk '{print $1}' \
			>"${RELDIR}/volume/data/lnd/walletpass.txt"
}
mk_systemd() {
	! [ -e "/etc/systemd/system/${CT_NAME}.service" ] \
	|| eprintln "service ${CT_NAME} already exists"
	local user="${USER}"
	sudo bash -c "cat << EOF > /etc/systemd/system/${CT_NAME}.service
[Unit]
Description=${CT_NAME}
After=network.target

[Service]
Environment=\"PATH=/usr/local/bin:/usr/bin:/bin:${PATH}\"
User=${user}
Type=forking
ExecStart=/bin/bash -c \"cd ${PWD}/${RELDIR}; ./control.sh up\"
ExecStop=/bin/bash -c \"cd ${PWD}/${RELDIR}; ./control.sh down\"
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
"
	sudo systemctl enable "${CT_NAME}".service
	sudo systemctl start "${CT_NAME}".service
}
rm_systemd() {
	[ -e "/etc/systemd/system/${CT_NAME}.service" ] || return 0
	sudo systemctl stop "${CT_NAME}".service || true
	sudo systemctl disable "${CT_NAME}".service
	sudo rm /etc/systemd/system/"${CT_NAME}".service
}
build() {
	podman build \
	-f "${RELDIR}/Containerfile" \
	--tag "${IMG_NAME}" \
	"${RELDIR}"
}
up() {
	podman run --rm \
		-p ${EXT_PORT}:8080 \
		-v ${RELDIR}/volume:/app \
		-v ${RELDIR}/volume/data/lnd:/root/.lnd \
		-v ${RELDIR}/lnd.conf:/root/.lnd/lnd.conf \
		--name "${CT_NAME}" \
		"localhost/${IMG_NAME}" 2>&1 | tee -a ${RELDIR}/volume/data/ct.log &
}
down() {
	podman stop "${IMG_NAME}" || true
}
clean() {
	printf "Are you sure you want to delete the data? (Y/n): "
	read v
	[ "${v}" == "Y" ] || eprintln 'ABORT'
	rm -rf "${RELDIR}/volume/data"
}
lncli() {
	! [ -z "${1}" ] || eprintln 'Expected lncli args'
	podman exec -it "${CT_NAME}" bash -c "lncli ${1}"
}
####################
common
####################
case ${1} in
	build) build ;;
	up) up ;;
	down) down ;;
	clean) clean ;;
	mk-systemd) mk_systemd ;;
	rm-systemd) rm_systemd ;;
	lncli) lncli "${2}" ;;
	*) eprintln "${HELP_MSG}" ;;
esac

