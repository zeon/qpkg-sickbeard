#!/bin/sh

QPKG_DIR=

find_base()
{
    BASE=
    publicdir=`/sbin/getcfg $PUBLIC_SHARE path -f /etc/config/smb.conf`
    if [ ! -z $publicdir ] && [ -d $publicdir ];then
      publicdirp1=`/bin/echo $publicdir | /bin/cut -d "/" -f 2`
      publicdirp2=`/bin/echo $publicdir | /bin/cut -d "/" -f 3`
      publicdirp3=`/bin/echo $publicdir | /bin/cut -d "/" -f 4`
      if [ ! -z $publicdirp1 ] && [ ! -z $publicdirp2 ] && [ ! -z $publicdirp3 ]; then
            [ -d "/${publicdirp1}/${publicdirp2}/${PUBLIC_SHARE}" ] && BASE="/${publicdirp1}/${publicdirp2}"
      fi
    fi

    # Determine BASE installation location by checking where the Public folder is.
    if [ -z $BASE ]; then
      for datadirtest in /share/HDA_DATA /share/HDB_DATA /share/HDC_DATA /share/HDD_DATA /share/MD0_DATA /share/MD1_DATA; do
              [ -d $datadirtest/$PUBLIC_SHARE ] && BASE="/${publicdirp1}/${publicdirp2}"
      done
    fi
    if [ -z $BASE ] ; then
        echo "The Public share not found."
        exit 1
    fi

    QPKG_DIR=${BASE}/.qpkg/${QPKG_NAME}
}

find_base

# only remove the one we created
[ "`/bin/readlink /usr/bin/start-stop-daemon`" = "${QPKG_DIR}/bin/start-stop-daemon" ] && /bin/rm /usr/bin/start-stop-daemon

#remove injected code
awk '/## added by sickbeard/{c=4}!(c&&c--)' /etc/init.d/sabnzbd.sh > ./tmp
chmod +x ./tmp
mv ./tmp /etc/init.d/sabnzbd.sh








