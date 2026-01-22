#!/usr/bin/env bash

set -e

# Options for starting Ganesha
: ${GANESHA_LOGFILE:="/dev/stdout"}
: ${GANESHA_PID:="/var/run/ganesha.pid"}
: ${GANESHA_CONFIGFILE:="/etc/ganesha/ganesha.conf"}
: ${GANESHA_OPTIONS:="-N NIV_EVENT"} # NIV_DEBUG
: ${GANESHA_EPOCH:=""}
: ${GANESHA_EXPORT_ID:="69"}
: ${GANESHA_EXPORT:="/export"}
: ${GANESHA_NFS_PROTOCOLS:="3,4"}
: ${GANESHA_TRANSPORTS:="UDP,TCP"}

# Docs: https://github.com/nfs-ganesha/nfs-ganesha/blob/next/src/doc/man/ganesha-export-config.rst
function bootstrap_config {
	echo "Bootstrapping Ganesha NFS config"
	mkdir -p `dirname ${GANESHA_CONFIGFILE}`
	cat <<END >${GANESHA_CONFIGFILE}

# Config taken from: https://github.com/kubernetes-incubator/external-storage/blob/master/nfs/pkg/server/server.go
EXPORT
{
	# Export Id (mandatory, each EXPORT must have a unique Export_Id)
	Export_Id = ${GANESHA_EXPORT_ID};
	# Exported path (mandatory)
	Path = ${GANESHA_EXPORT};
	# Pseudo Path (required for NFS v4)
	Pseudo = /;
	# Required for access (default is None)
	# Could use CLIENT blocks instead
	Access_Type = RW;
	# Exporting FSAL

	SecType = "sys";
	Squash = No_Root_Squash;

	FSAL {
		Name = VFS;
	}
}

NFS_Core_Param
{
	MNT_Port = 20048;
	fsid_device = true;
	Protocols = ${GANESHA_NFS_PROTOCOLS};
}

NFSV4
{
	Grace_Period = 90;
}

END

	chmod 0600 ${GANESHA_CONFIGFILE}

}

function bootstrap_export {
	if [ ! -f ${GANESHA_EXPORT} ]; then
		mkdir -p "${GANESHA_EXPORT}"
  	fi
}

function init_dbus {
	echo "Starting dbus"
	rm -f /var/run/dbus/system_bus_socket
	rm -f /var/run/dbus/pid
	dbus-uuidgen --ensure
	dbus-daemon --system --fork
	sleep 2
}

function init {
	echo "Starting rpcbind"
	/usr/sbin/rpcbind -w
	sleep 2

	/usr/sbin/rpc.statd -L
	sleep 2

	init_dbus
	sleep 2

	rm -rf /usr/local/var/run/ganesha
	mkdir -p /usr/local/var/lib/nfs/ganesha
}

bootstrap_config
bootstrap_export

init

echo "Starting Ganesha NFS"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
exec ganesha.nfsd -F -L ${GANESHA_LOGFILE} -p ${GANESHA_PID} -f ${GANESHA_CONFIGFILE} ${GANESHA_ADDITIONAL_OPTIONS}
