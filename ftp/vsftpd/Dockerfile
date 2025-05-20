FROM debian:bullseye

RUN apt-get update && apt-get install -y vsftpd=3.0.3-* \
    && rm -rf /var/lib/apt/lists/*

COPY vsftpd.conf /etc/vsftpd.conf
RUN mkdir -p /home/ftp && chmod 755 /home/ftp

EXPOSE 21 21000-21010
CMD ["vsftpd", "/etc/vsftpd.conf"] 

