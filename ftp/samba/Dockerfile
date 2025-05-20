FROM debian:latest
RUN apt-get update && apt-get install -y samba
COPY ./samba-4.7.0 /etc/samba
EXPOSE 139 445
CMD ["smbd", "-F", "--no-process-group"]
