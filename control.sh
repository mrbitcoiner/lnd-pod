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
	! [ -z "${EXT_REST_PORT}" ] || eprintln 'undefined env EXT_REST_PORT'
	! [ -z "${EXT_LIGHTNING_PORT}" ] || eprintln 'undefined env EXT_LIGHTNING_PORT'
}
common() {
	mkdir -p "${RELDIR}/volume/data/lnd"
	chmod +x "${RELDIR}"/volume/scripts/*.sh
	check_env
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
	printf "To start the service, run: sudo systemctl start "${CT_NAME}".service\n"
	
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
	[ -e "${RELDIR}/volume/data/lnd/walletpass.txt" ] || create_wallet
	podman run --rm \
		-p ${EXT_REST_PORT}:8080 \
		-p ${EXT_LIGHTNING_PORT}:9735 \
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
create_wallet() {
	! [ -e "${RELDIR}/volume/data/lnd/walletpass.txt" ] \
		|| eprintln "wallet already exists"
	printf "Wallet password: "
	read password
	printf "\n"
	printf "${password}" | grep -E '^.{8,256}$' 1>/dev/null || \
		eprintln 'password must have at least 8 chars'
	printf "${password}" > ${RELDIR}/volume/data/lnd/walletpass.txt
	podman ps --format="{{.Names}}" | grep "${CT_NAME}" 1>/dev/null 2>&1 || up
	sleep 5
	podman exec -it "${CT_NAME}" bash -c "lncli create"
	printf "Wallet created!"
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

