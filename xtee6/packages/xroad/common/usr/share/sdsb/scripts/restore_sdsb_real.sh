#!/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}


if [ "$(id -nu )" != "root" ] 
then
 die "ABORTED. This script must run under root user "
fi

[ "$#" -eq 1 ] || die "1 argument required, $# provided. Give path to backup file"

filename=$1

tar tf ${filename} > /dev/null

if [ "x$?" != "x0" ]
then 
 die "${filename} is broken. Aborting restore!"
fi

echo "STOP ALL SERVICES EXCEPT JETTY"

SERVICES=$(initctl list | grep -E  "^xroad-|^xtee55-" | grep -v -- -jetty | cut -f 1 -d " "  )

for xrdservice in $SERVICES; do  initctl stop $xrdservice  ;done

##

listf="`find /etc/sdsb/ -type f` /etc/nginx/sites-enabled/*"

echo "CREATING PRE-RESTORE BACKUP"

if [ -x /usr/share/sdsb/scripts/backup_db.sh ]
then
  echo "Creating database dump to /var/lib/sdsb/dbdump.dat"
  /usr/share/sdsb/scripts/backup_db.sh
  listf="${listf} /var/lib/sdsb/dbdump.dat"
fi


echo -e "Backing up following files to  /var/lib/sdsb/conf_prerestore_backup.tar \n ${listf}"
tar cf /var/lib/sdsb/conf_prerestore_backup.tar ${listf}
rm ${listf}

echo -e "\n-----\n RESTORING CONFIGURATION FROM ${filename}\nRestoring files:\n"
tar xfv ${filename} -C /

if [ -x /usr/share/sdsb/scripts/restore_db.sh ] &&  [ -e /var/lib/sdsb/dbdump.dat ]
then
  echo -e "\nRESTORING DATABASE FROM /var/lib/sdsb/dbdump.dat\n"
  /usr/share/sdsb/scripts/restore_db.sh 1>/dev/null
fi

echo -e "\nRESTARING SERVICES\n"

for xrdservice in $SERVICES; do  initctl start $xrdservice ;done
