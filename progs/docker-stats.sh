#!/bin/bash
#/*
# *
# * LibreNMS Docker info discovery agent for Linux / Proxmox
# *
# * @package    LibreNMS
# * @link       https://www.librenms.org
# *
# * @author     Peca Nesovanovic <peca.nesovanovic@sattrakt.com>
# * @copyright  2023 Peca Nesovanovic
# */
#
# Usage:
# /etc/crontab
# */6 * * * * root /etc/snmp/docker-stats -u

# shellcheck source=/dev/null
source /etc/snmp/snmp.data
FILE="${TMPDIR}/out_docker_info"
DFILE="${TMPDIR}/dbg_docker_info"
mkdir -p "$TMPDIR"

date +%X > "$DFILE"
echo "$1" >> "$DFILE"

[ -z "$1" ] && {
    [ -f "${FILE}" ] && cat "$FILE"
    exit
}

rm -f "${FILE}"
ERR=
[ -z $(which jq) ] && { ERR="${ERR}JQ missing, "; ERRINT=1; }
[ -z $(which docker) ] && { ERR="${ERR}DOCKER missing, "; ERRINT=1; }

JSONSTART="{\"version\":\"2\",\"data\":["
[ -z "$ERR" ] && {
    ERRINT=0
    STAT=$(docker stats -a --no-stream|tail -n +2);
    [ ! -z "$STAT" ] && {
        JSONROW=""
        while IFS= read -a line; do
            OUT=$(echo $line|xargs|sed "s/ \/ /,/g"|tr ' ' ',')
            IMGID=$(echo $OUT|cut -d',' -f1)
            IMGSTAT=$(docker inspect --format='{{.State.Status}}' $IMGID|xargs)
            TEMP=${IMGSTAT},${OUT}
            ARR=(${TEMP//,/ })
            JSOND="{\"container\":\"${ARR[2]}\",\"cpu\":\"${ARR[3]}\",\"pids\":\"${ARR[11]}\""
            JSONMEM=",\"memory\":{\"used\":\"${ARR[4]}\",\"limit\":\"${ARR[5]}\",\"perc\":\"${ARR[6]}\"}"
            JSONNET=",\"net\":{\"rx\":\"${ARR[7]}\",\"tx\":\"${ARR[8]}\"}"
            JSONIO=",\"io\":{\"r\":\"${ARR[9]}\",\"w\":\"${ARR[10]}\"}"
            JSONSTATE=",\"state\":{\"status\":\"${ARR[0]}\"}"
            [ -n "$JSONROW" ] && JSONROW="${JSONROW},"
            JSONROW=${JSONROW}${JSOND}${JSONMEM}${JSONNET}${JSONIO}$JSONSTATE"}"
        done <<< "$STAT"
    }
}

JSONEND="],\"error\":\"$ERRINT\",\"errorString\":\"$ERR\"}"
echo "${JSONSTART}${JSONROW}${JSONEND}" > "${FILE}"

chmod 644 "${FILE}"
