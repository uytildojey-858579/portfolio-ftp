### **VSFTPD**

'''
mkdir -p /home/ftp/admin
'''
- puis

'''
sudo docker run --name vsftpd --rm -it \
  --network host \
  -e FTP_USER=admin \
  -e FTP_PASSWORD=admin \
  -v /home/ftp/admin:/srv/admin \
  monteops/vsftpd
'''
