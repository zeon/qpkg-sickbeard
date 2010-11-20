#! /bin/sh

### BEGIN INIT INFO
# Provides:          Sick Beard application instance
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts instance of Sick Beard
# Description:       starts instance of Sick Beard using start-stop-daemon
### END INIT INFO

############### EDIT ME ##################

PUBLIC_SHARE=`/sbin/getcfg SHARE_DEF defPublic -d Public -f /etc/config/def_share.info`
DOWNLOAD_SHARE=`/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info`

QPKG_NAME=SickBeard
QPKG_DIR=
PID_FILE=/var/run/sickbeard.pid
DAEMON=/usr/bin/python
DAEMON_OPTS=" SickBeard.py -q"
RUN_AS=admin

check_python(){
	#python2.7 dependency checking
	PYTHON_INSTALL_PATH=`/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf`
	if [ "${PYTHON_INSTALL_PATH}" == "" ]; then
		/sbin/write_log "Failed to start SickBeard, No Python runtime is found. Please re-install Python." 1
		exit 1
	fi
}

check_sabnzbdplus(){
    #sabnzbdplus dependency checking
    SABNZBDPLUS_INSTALL_PATH=`/sbin/getcfg SABnzbdplus Install_Path -f /etc/config/qpkg.conf`
    if [ "${SABNZBDPLUS_INSTALL_PATH}" == "" ]; then
		SABNZBDPLUS_INSTALL_PATH=`/sbin/getcfg SABnzbd+ Install_Path -f /etc/config/qpkg.conf`
		if [ "${SABNZBDPLUS_INSTALL_PATH}" == "" ]; then		
	        /sbin/write_log "Failed to start SickBeard, SABnzbdplus is not found. Please install SABnzbdplus first." 1
    	    exit 1
		fi
	fi
}

# Determine BASE installation location according to smb.conf
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

create_req_dirs(){
	[ ! -d "/share/${DOWNLOAD_SHARE}" ] && _exit 1
	[ -d "/share/${DOWNLOAD_SHARE}/sickbeard" ] || /bin/mkdir "/share/${DOWNLOAD_SHARE}/sickbeard"
	/bin/chmod 777 /share/$DOWNLOAD_SHARE/sickbeard		
}

create_links(){
		[ -f /usr/bin/start-stop-daemon ] || ln -sf ${QPKG_DIR}/bin/start-stop-daemon /usr/bin/start-stop-daemon
}

inject_sb_startup_procedure() {
	[ -f /etc/init.d/sabnzbd.sh ] && [ ! "`grep "## added by sickbeard" /etc/init.d/sabnzbd.sh`" ] && awk '{gsub("/bin/sleep 5","/bin/sleep 5\n\n\t\t## added by sickbeard\n\t\tif [ \"`/sbin/getcfg SickBeard Install_Path -f /etc/config/qpkg.conf`\" != \"\" ] \\&\\& [ \"`/sbin/getcfg SickBeard Enable -f /etc/config/qpkg.conf`\" = \"TRUE\" ]; then\n\t\t\t/etc/init.d/sickbeard.sh restart\n\t\tfi");print}' /etc/init.d/sabnzbd.sh > /tmp/sabnzbd.sh

	if [ -f /tmp/sabnzbd.sh ]; then
		chmod +x /tmp/sabnzbd.sh; 
		mv /tmp/sabnzbd.sh /etc/init.d/sabnzbd.sh
	fi
}

config_sickbeard() {
	if [ -f /root/.sabnzbd/sabnzbd.ini ] && [ -f ${QPKG_DIR}/config.ini ]; then
		setcfg SABnzbd sab_username `getcfg misc username -f /root/.sabnzbd/sabnzbd.ini` -f ${QPKG_DIR}/config.ini
		setcfg SABnzbd sab_password `getcfg misc password -f /root/.sabnzbd/sabnzbd.ini` -f ${QPKG_DIR}/config.ini
		setcfg SABnzbd sab_apikey `getcfg misc api_key -f /root/.sabnzbd/sabnzbd.ini` -f ${QPKG_DIR}/config.ini
		
		setcfg NZBMatrix nzbmatrix_username `getcfg nzbmatrix username -f /root/.sabnzbd/sabnzbd.ini` -f ${QPKG_DIR}/config.ini
		setcfg NZBMatrix nzbmatrix_apikey `getcfg nzbmatrix apikey -f /root/.sabnzbd/sabnzbd.ini` -f ${QPKG_DIR}/config.ini
	fi
	if [ -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg ] && [ -f ${QPKG_DIR}/config.ini ]; then
		setcfg SickBeard host `getcfg General web_host -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		setcfg SickBeard port `getcfg General web_port -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		setcfg SickBeard username `getcfg General web_username -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		setcfg SickBeard password `getcfg General web_password -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
	fi	
}

config_sabnzbdplus() {
	if [ -f /root/.sabnzbd/sabnzbd.ini ] && [ -f ${QPKG_DIR}/config.ini ]; then
		setcfg misc script_dir "${QPKG_DIR}/autoProcessTV" -f /root/.sabnzbd/sabnzbd.ini
		setcfg misc enable_tv_sorting 0 -f /root/.sabnzbd/sabnzbd.ini
		
		setcfg [tv] script sabToSickBeard.py -f /root/.sabnzbd/sabnzbd.ini
		setcfg [tv] dir TV -f /root/.sabnzbd/sabnzbd.ini
	fi
	
	inject_sb_startup_procedure
}

case "$1" in
  start)
		check_python
		check_sabnzbdplus

        echo "Starting $QPKG_NAME"
		if [ `/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f /etc/config/qpkg.conf` = UNKNOWN ]; then
		    /sbin/setcfg ${QPKG_NAME} Enable TRUE -f /etc/config/qpkg.conf
		elif [ `/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f /etc/config/qpkg.conf` != TRUE ]; then
		    echo "${QPKG_NAME} is disabled."
		    exit 1
		fi

		create_links
		create_req_dirs

		config_sickbeard
		config_sabnzbdplus
		
        /usr/bin/start-stop-daemon -d $QPKG_DIR -c $RUN_AS --start --background --pidfile $PID_FILE  --make-pidfile --exec $DAEMON -- $DAEMON_OPTS
        ;;
  stop)
        echo "Stopping $QPKG_NAME"
        /usr/bin/start-stop-daemon --stop --pidfile $PID_FILE
		while [ "`ps |grep SickBeard.py |grep -v grep |awk '{ print $1 }'`" != "" ]
		do
			sleep 1
		done
		
        ;;

  restart|force-reload)
        echo "Restarting $QPKG_NAME"
        if [ "`ps |grep SickBeard.py |grep -v grep |awk '{ print $1 }'`" != "`cat $PID_FILE`" ]; then
			$0 start
		else
			$0 stop 
			$0 start
		fi
        ;;
  *)
        N=/etc/init.d/$QPKG_NAME
        echo "Usage: $N {start|stop|restart|force-reload}" >&2
        exit 1
        ;;
esac

exit 0
