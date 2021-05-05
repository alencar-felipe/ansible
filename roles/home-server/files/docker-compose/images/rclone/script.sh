#!/bin/sh

while true
do
    rclone sync /data remote:/
	echo "synced."
	sleep 86400
done

