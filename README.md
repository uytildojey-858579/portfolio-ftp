# IMPORTANT
- Il faut lire le README.md pour pouvoir comprendre les problèmes et l'installation
# portfolio-ftp
- Ce repository comporte un portfolio sous docker, et un serveur ftp. Ils sont conçus avec des vulns
# Requis
- Installer docker et docker-compose
# Lancement site 
- sudo ./start.sh
- Ne pas oublié de l'éxecuté en mode administrateur !
# Pour le site et db
- Bien lire le docker-compose.yml pour savoir les identifiants de la base de donné
- L'identifiant et mot de passe du site: stage:stage
- Pour voir le site accéder à: localhost:8080 ou @IP:8080
- Pour voir phpmyadmin : localhost:8080/phpmyadmin ou @IP:8080/phpmyadmin
- Il faut exploité 4 CVE, celle de apache 2.4(CVE-2019-0211), PHP 7.1 (CVE-2019-11043),
- WordPress 5.0(CVE-2019-8943), phpMyAdmin 4.8.1(CVE-2018-12613), MySQL 5.7.21(CVE-2018-2562)
- Ces CVE ont toutes plus de 5 ans (repo publié 2025)
- Pour voir si un docker est actif : docker ps
# Lancement samba
- aller dans ftp/samba
- sudo docker-compose up -d
# Lancement vsftpd
- sudo ./start.sh

