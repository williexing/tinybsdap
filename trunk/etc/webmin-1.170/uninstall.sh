#!/bin/sh
printf "Are you sure you want to uninstall Webmin? (y/n) : "
read answer
printf "\n"
if [ "$answer" = "y" ]; then
	/etc/webmin-1.170/stop
	echo "Running uninstall scripts .."
	(cd "/usr/share/webmin-1.170" ; WEBMIN_CONFIG=/etc/webmin-1.170 WEBMIN_VAR=/var/webmin LANG= "/usr/share/webmin-1.170/run-uninstalls.pl")
	echo "Deleting /usr/share/webmin-1.170 .."
	rm -rf "/usr/share/webmin-1.170"
	echo "Deleting /etc/webmin-1.170 .."
	rm -rf "/etc/webmin-1.170"
	echo "Done!"
fi
