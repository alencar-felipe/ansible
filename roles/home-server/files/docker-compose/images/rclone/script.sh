#!/bin/sh

while true
do
    echo "starting rclone."
    rclone sync /data remote:/
	echo "synced."
	sleep 86400
done

