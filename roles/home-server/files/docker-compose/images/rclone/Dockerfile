FROM rclone/rclone

RUN mkdir /app

ADD script.sh /app/script.sh

RUN chmod +x /app/script.sh

ENTRYPOINT /app/script.sh