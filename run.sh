#!/bin/sh
set -e
if [ ! -z "${SSH_KEY}" ]; then
/usr/bin/set_root_pw.sh
exec /usr/sbin/sshd -D
fi
exec "$@"
bash