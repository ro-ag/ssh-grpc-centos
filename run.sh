set -e

/usr/bin/set_root_pw.sh

if [ ! -z "${SSH_KEY}" ]; then
exec /usr/sbin/sshd -D
fi
#source /opt/rh/gcc-toolset-9/enable
exec "$@"