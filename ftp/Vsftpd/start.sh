#!/bin/bash

sudo docker run --name vsftpd --rm -it -p 21:21 -p 4559-4564:4559-4564 -e FTP_USER=ftpuser -e FTP_PASSWORD=ftppassword monteops/vsftpd bash
