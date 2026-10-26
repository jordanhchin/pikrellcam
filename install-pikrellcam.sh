#!/bin/bash

PGM=`basename $0`

if [ `id -u` == 0 ]
then
    echo -e "$PGM should not be run as root.\n"
    exit 1
fi

bad_install()
	{
	echo "Cannot find $1 in $PWD"
	echo "Are you running $PGM in the install directory?"
	exit 1
	}

if [ ! -x $PWD/pikrellcam ]
then
	bad_install "program pikrellcam"
fi

if [ ! -d $PWD/www ]
then
	bad_install "directory www"
fi

sudo chown :www-data $PWD/www
sudo chmod 775 $PWD/www

if [ ! -d media ]
then
	mkdir media media/archive media/videos media/thumbs media/stills
	sudo chown :www-data media media/archive media/videos media/thumbs media/stills
	sudo chmod 775 media media/archive media/videos media/thumbs media/stills
fi

if [ ! -h www/media ]
then
	ln -s $PWD/media www/media
fi

if [ ! -h www/archive ]
then
	ln -s $PWD/media/archive www/archive
fi

echo ""
echo "Set the port for the nginx web server."
echo "If you already have a web server configuration using the default"
echo "port 80, you should enter an alternate port for PiKrellCam."
echo "Otherwise you can use the default port 80 or an alternate as you wish."
echo "The port number will be set in: /etc/nginx.sites-available/pikrellcam."
echo -n "Enter web server port: "
read resp
if [ "$resp" == "" ]
then
	PORT=80
else
	PORT=$resp
fi

echo ""
echo "PiKrellCam is installed as a systemd service which can be enabled to start"
echo "at boot.  If you don't start at boot, PiKrellCam can always be started and"
echo "stopped from the web page."
echo -n "Do you want PiKrellCam to be auto started at boot? (yes/no): "
read resp
if [ "$resp" == "y" ] || [ "$resp" == "yes" ]
then
	AUTOSTART=yes
else
	AUTOSTART=no
fi


HTPASSWD=www/.htpasswd
PASSWORD=""

echo ""
if [ -f $HTPASSWD ]
then
	echo "A web password is already set."
	echo -n "Do you want to change the password (yes/no)? "
	read resp
	if [ "$resp" == "y" ] || [ "$resp" == "yes" ]
	then
		SET_PASSWORD=yes
		rm -f $HTPASSWD
	else
		SET_PASSWORD=no
	fi
else
	SET_PASSWORD=yes
fi

if [ "$SET_PASSWORD" == "yes" ]
then
	# A web password is required: the web page can control the camera,
	# delete media and reboot the Pi.
	echo "Enter a password for a web page login for user: $USER"
	while true
	do
		echo -n "Enter password: "
		read -s PASSWORD
		echo ""
		if [ "$PASSWORD" == "" ]
		then
			echo "The password cannot be blank."
			continue
		fi
		echo -n "Enter password again: "
		read -s PASSWORD2
		echo ""
		if [ "$PASSWORD" != "$PASSWORD2" ]
		then
			echo "The passwords do not match."
			continue
		fi
		break
	done
fi




echo ""
echo "Starting PiKrellCam install..."

# =============== apt install needed packages ===============
#
JESSIE=8
STRETCH=9
BUSTER=10

V=`cat /etc/debian_version`
#DEB_VERSION="${V:0:1}"
# Strip all chars after decimal point
DEB_VERSION="${V%.*}"

PACKAGE_LIST=""

if ((DEB_VERSION >= BUSTER))
then
	# Use the distribution's default (and security supported) PHP version.
	AV_PACKAGES="ffmpeg"
	PHP_PACKAGES="php-fpm php-common"
elif ((DEB_VERSION >= STRETCH))
then
	AV_PACKAGES="libav-tools"
	PHP_PACKAGES="php7.0 php7.0-common php7.0-fpm"
else
	AV_PACKAGES="libav-tools"
	PHP_PACKAGES="php5 php5-common php5-fpm"
fi

for PACKAGE in $PHP_PACKAGES $AV_PACKAGES
do
	if ! dpkg -s $PACKAGE 2>/dev/null | grep Status | grep -q installed
	then
		PACKAGE_LIST="$PACKAGE_LIST $PACKAGE"
	fi
done

for PACKAGE in gpac nginx bc \
	sshpass mpack imagemagick apache2-utils libasound2 libasound2-dev \
	libmp3lame0 libmp3lame-dev
do
	if ! dpkg -s $PACKAGE 2>/dev/null | grep Status | grep -q installed
	then
		PACKAGE_LIST="$PACKAGE_LIST $PACKAGE"
	fi
done

if [ "$PACKAGE_LIST" != "" ]
then
	echo "Installing packages: $PACKAGE_LIST"
	echo "Running: apt-get update"
	sudo apt-get update
	sudo apt-get install -y --no-install-recommends $PACKAGE_LIST
else
	echo "No packages need to be installed."
fi


if ((DEB_VERSION < JESSIE))
then
	if ! dpkg -s realpath 2>/dev/null | grep Status | grep -q installed
	then
		echo "Installing package: realpath"
		sudo apt-get install -y --no-install-recommends realpath
	fi
fi


if [ ! -h /usr/local/bin/pikrellcam ]
then
    echo "Making /usr/local/bin/pikrellcam link."
	sudo rm -f /usr/local/bin/pikrellcam
    sudo ln -s $PWD/pikrellcam /usr/local/bin/pikrellcam
else
    CURRENT_BIN=`realpath /usr/local/bin/pikrellcam`
    if [ "$CURRENT_BIN" != "$PWD/pikrellcam" ]
    then
    echo "Replacing /usr/local/bin/pikrellcam link"
        sudo rm /usr/local/bin/pikrellcam
        sudo ln -s $PWD/pikrellcam /usr/local/bin/pikrellcam
    fi
fi


# =============== create initial ~/.pikrellcam configs ===============
#
./pikrellcam -quit

if [ "$USER" == "pi" ]
then
	rm -f www/user.php
else
	printf "<?php
    \$e_user = "$USER";
?>
" > www/user.php
fi

# =============== set install_dir in pikrellcam.conf ===============
#
PIKRELLCAM_CONF=$HOME/.pikrellcam/pikrellcam.conf
if [ ! -f $PIKRELLCAM_CONF ]
then
	echo "Unexpected failure to create config file $HOME/.pikrellcam/pikrellcam.conf"
	exit 1
fi

if ! grep -q "install_dir $PWD" $PIKRELLCAM_CONF
then
	echo "Setting install_dir config line in $PIKRELLCAM_CONF:"
	echo "install_dir $PWD"
	sed -i  "/install_dir/c\install_dir $PWD" $PIKRELLCAM_CONF
fi


# =============== pikrellcam systemd service  ===============
#
SERVICE=/etc/systemd/system/pikrellcam.service
echo "Installing $SERVICE"
sed "s|INSTALL_DIR|$PWD|g; s|USER|$USER|" etc/pikrellcam.service > /tmp/pikrellcam.service.tmp
sudo mv /tmp/pikrellcam.service.tmp $SERVICE
sudo chown root:root $SERVICE
sudo chmod 644 $SERVICE
sudo systemctl daemon-reload

# Older installs started pikrellcam from rc.local.
if [ -f /etc/rc.local ] && grep -q pikrellcam /etc/rc.local
then
	echo "Removing old pikrellcam autostart line from /etc/rc.local."
	sudo sed -i "/pikrellcam/d" /etc/rc.local
fi

if [ "$AUTOSTART" == "yes" ]
then
	echo "Enabling pikrellcam service to start at boot."
	sudo systemctl enable pikrellcam
else
	sudo systemctl disable pikrellcam 2>/dev/null
fi


# ===== sudoers permission for www-data to start/stop the service ======
#
if ! cmp -s etc/pikrellcam.sudoers /etc/sudoers.d/pikrellcam
then
	echo "Installing /etc/sudoers.d/pikrellcam: www-data permission to start"
	echo "    and stop the pikrellcam service."
	cp etc/pikrellcam.sudoers /tmp/pikrellcam.sudoers.tmp
	if sudo visudo -c -f /tmp/pikrellcam.sudoers.tmp > /dev/null
	then
		sudo chown root:root /tmp/pikrellcam.sudoers.tmp
		sudo chmod 440 /tmp/pikrellcam.sudoers.tmp
		sudo mv /tmp/pikrellcam.sudoers.tmp /etc/sudoers.d/pikrellcam
	else
		echo "Error: etc/pikrellcam.sudoers failed visudo check, not installed."
		rm -f /tmp/pikrellcam.sudoers.tmp
	fi
fi

# =============== Setup Password  ===============
#
OLD_SESSION_PATH=www/session
if [ -d $OLD_SESSION_PATH ]
then
	sudo rm -rf $OLD_SESSION_PATH
fi

OLD_PASSWORD=www/password.php
if [ -f $OLD_PASSWORD ]
then
	rm -f $OLD_PASSWORD
fi

if [ "$PASSWORD" != "" ]
then
	# -i reads the password from stdin so it is not visible in ps.
	echo "$PASSWORD" | htpasswd -ic $HTPASSWD $USER
	sudo chown $USER:www-data $HTPASSWD
	sudo chmod 640 $HTPASSWD
fi


# =============== nginx install ===============
#
# Logging can eat many tens of megabytes of SD card space per day
# with the mjpeg.jpg streaming
#
if ! grep -q "access_log off" /etc/nginx/nginx.conf
then
	echo "Turning off nginx access_log."
	sudo sed -i  '/access_log/c\	access_log off;' /etc/nginx/nginx.conf
fi

if ((DEB_VERSION < JESSIE))
then
	NGINX_SITE=etc/nginx-wheezy-site-default
else
	NGINX_SITE=etc/nginx-jessie-site-default
fi

echo "Installing /etc/nginx/sites-available/pikrellcam"
echo "    nginx web server port: $PORT"
echo "    nginx web server root: $PWD/www"
sudo cp $NGINX_SITE /etc/nginx/sites-available/pikrellcam
sudo sed -i "s|PIKRELLCAM_WWW|$PWD/www|; \
			s/PORT/$PORT/" \
			/etc/nginx/sites-available/pikrellcam

if ((DEB_VERSION >= BUSTER))
then
	# php-fpm installs /usr/sbin/php-fpmX.Y
	PHP_VERSION=`ls /usr/sbin/php-fpm* 2>/dev/null | sed -n 's|.*php-fpm||p' | sort -V | tail -1`
	PHP_FPM_SOCK=/run/php/php$PHP_VERSION-fpm.sock
	PHP_FPM_SERVICE=php$PHP_VERSION-fpm
elif ((DEB_VERSION >= STRETCH))
then
	PHP_VERSION=7.0
	PHP_FPM_SOCK=/run/php/php7.0-fpm.sock
	PHP_FPM_SERVICE=php7.0-fpm
else
	PHP_VERSION=5
	PHP_FPM_SOCK=/var/run/php5-fpm.sock
	PHP_FPM_SERVICE=php5-fpm
fi
echo "    PHP version: $PHP_VERSION  socket: $PHP_FPM_SOCK"
sudo sed -i "s|PHP_FPM_SOCK|$PHP_FPM_SOCK|" /etc/nginx/sites-available/pikrellcam

# PiKrellCam takes no file uploads, so turn off PHP upload handling.
# This also reduces exposure to PHP request-parsing vulnerabilities.
PHP_INI_DIR=/etc/php/$PHP_VERSION/fpm/conf.d
if [ -d $PHP_INI_DIR ]
then
	echo "Installing $PHP_INI_DIR/99-pikrellcam.ini"
	sudo cp etc/php-pikrellcam.ini $PHP_INI_DIR/99-pikrellcam.ini
	sudo chmod 644 $PHP_INI_DIR/99-pikrellcam.ini
	sudo service $PHP_FPM_SERVICE restart
fi

NGINX_SITE=/etc/nginx/sites-available/pikrellcam

if [ "$PORT" == "80" ]
then
	NGINX_LINK=/etc/nginx/sites-enabled/default
	CURRENT_SITE=`realpath $NGINX_LINK`
	if [ "$CURRENT_SITE" != "$NGINX_SITE" ]
	then
		echo "Changing $NGINX_LINK link to pikrellcam"
		sudo rm -f $NGINX_LINK
		sudo ln -s $NGINX_SITE $NGINX_LINK
	fi
else
	NGINX_LINK=/etc/nginx/sites-enabled/pikrellcam
fi

if [ ! -h $NGINX_LINK 2>/dev/null ]
then
	echo "Adding $NGINX_LINK link to sites-available/pikrellcam."
	sudo ln -s $NGINX_SITE $NGINX_LINK
fi

if [ ! -f $HTPASSWD ]
then
	echo "Error: a password for the web page is not set ($HTPASSWD missing)."
	echo "Rerun $PGM to set one.  The web page will not load until then."
fi

sudo service nginx restart


# =============== Setup FIFO  ===============
#
fifo=$PWD/www/FIFO

if [ ! -p "$fifo" ]
then
	rm -f $fifo
	mkfifo $fifo
fi
sudo chown $USER:www-data $fifo
sudo chmod 664 $fifo



# =============== copy scripts-dist into scripts  ===============
#
if [ ! -d scripts ]
then
	mkdir scripts
fi

cd scripts-dist

for script in *
do
	if [ ! -f ../scripts/$script ] && [ "${script:0:1}" != "_" ]
	then
		cp $script ../scripts 
	fi
done

echo ""
echo "Install finished."
echo "This install script does not automatically start pikrellcam."
echo "To start pikrellcam, open a browser page to:"
if [ "$PORT" == "80" ]
then
	echo "    http://your_pi"
else
	echo "    http://your_pi:$PORT"
fi
echo "and click on the \"System\" panel and then the \"Start PiKrellCam\" button."
echo "PiKrellCam can also be run from a Pi terminal for testing purposes."
if [ "$AUTOSTART" == "yes" ]
then
	echo "Automatic pikrellcam starting at boot is enabled."
fi
echo ""
