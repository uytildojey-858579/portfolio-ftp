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

# si vous plet moussier 
Voici une **procédure claire et complète** pour générer un certificat serveur AVEC SAN (Subject Alternative Name), le signer via ta CA existante, et l’installer sur Apache dans Docker.  
**Tu n’as pas besoin de refaire la CA** : tu utilises le même `ca_root.crt` et `ca_root.key` !

---

## 1. Sur le conteneur test_apache : Générer la clé privée (si pas déjà fait)

```bash
openssl genrsa -out server.key 2048
```

---

## 2. Créer le fichier de configuration CSR AVEC SAN

Crée un fichier `csr.conf` :

```ini name=csr.conf
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
C  = FR
ST = France
L  = Paris
O  = Brainrot_Italien
CN = site.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1   = site.local
DNS.2   = www.site.local
```

Adapter CN et DNS à ton domaine réel.

---

## 3. Générer la CSR AVEC SAN

```bash
openssl req -new -key server.key -out server.csr -config csr.conf
```

---

## 4. Copier la CSR (`server.csr`) sur la CA (PKI)

Utilise un volume partagé, `docker cp`, ou tout autre moyen.

---

## 5. Sur le conteneur PKI : Préparer un fichier d’extensions SAN pour la signature

Crée un fichier `v3_ext.conf` :

```ini name=v3_ext.conf
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = site.local
DNS.2 = www.site.local
```

---

## 6. Signer la CSR avec la CA pour générer le certificat serveur

```bash
openssl x509 -req -in server.csr -CA ca_root.crt -CAkey ca_root.key -CAcreateserial \
-out server.crt -days 365 -sha256 -extfile v3_ext.conf
```

---

## 7. Copier sur test_apache

- `server.key` (déjà là)
- `server.crt` (le certificat signé fraîchement créé)
- `ca_root.crt` (pour la chaîne de confiance)

---

## 8. Configurer Apache pour le HTTPS

Dans le fichier de conf SSL Apache (ex : `/etc/apache2/sites-available/default-ssl.conf`) :

```
SSLEngine on
SSLCertificateFile      /chemin/vers/server.crt
SSLCertificateKeyFile   /chemin/vers/server.key
SSLCertificateChainFile /chemin/vers/ca_root.crt
```

---

## 9. Activer SSL et recharger Apache

```bash
a2enmod ssl
a2ensite default-ssl
service apache2 reload
```

---

## 10. Importer le certificat racine (`ca_root.crt`) sur les machines clientes

- **Windows** : double-clique sur `ca_root.crt`
- **Linux** :  
  ```bash
  sudo cp ca_root.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  ```

---

## 11. Tester

Ouvre dans le navigateur :  
`https://site.local`  
**Pas d’avertissement HTTPS si le certificat racine est importé !**

---

### **Résumé visuel**
1. Génére clé privée + CSR sur test_apache (AVEC SAN)
2. Signe sur PKI avec la CA existante
3. Installe .crt, .key et ca_root.crt sur Apache
4. Importer ca_root.crt sur les clients
5. Profite du HTTPS !
---


### ** DNS **

Bien sûr ! Voici les grandes étapes pour installer et configurer ton projet avec Bind (DNS), Nginx (reverse proxy) et tes services (WordPress, Dashy, Gitea).  
**Je vais t’indiquer les commandes principales à chaque étape, sur Debian/Ubuntu (adapte si tu es sur une autre distribution).**

---

## 1. Installer Bind (serveur DNS) sur 192.168.30.10

```bash
sudo apt update
sudo apt install bind9 bind9utils bind9-doc
```

**Configurer la zone :**
- Édite `/etc/bind/named.conf.local` et ajoute :

```bash
zone "auth.local" {
    type master;
    file "/etc/bind/zones/db.auth.local";
};
```

- Crée le dossier si besoin :  
  `sudo mkdir -p /etc/bind/zones`
- Crée le fichier `/etc/bind/zones/db.auth.local` :

```dns
$TTL 604800
@   IN  SOA ns.auth.local. admin.auth.local. (
        2       ; Serial
        604800  ; Refresh
        86400   ; Retry
        2419200 ; Expire
        604800) ; Negative Cache TTL
;
@       IN  NS      ns.auth.local.
ns      IN  A       192.168.30.10
wordpress   IN  A   192.168.30.100
gitea       IN  A   192.168.30.100
dashy       IN  A   192.168.30.100
```

- Redémarre Bind :

```bash
sudo systemctl restart bind9
```

- **Pense à configurer tes clients pour utiliser 192.168.30.10 comme DNS !**

---

## 2. Installer Nginx (reverse proxy) sur 192.168.30.100

```bash
sudo apt update
sudo apt install nginx
```

**Exemple de config `/etc/nginx/sites-available/proxy` :**

```nginx
server {
    listen 80;
    server_name wordpress.auth.local;

    location / {
        proxy_pass http://192.168.30.20:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
server {
    listen 80;
    server_name gitea.auth.local;

    location / {
        proxy_pass http://192.168.30.90:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
server {
    listen 80;
    server_name dashy.auth.local;

    location / {
        proxy_pass http://192.168.30.90:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Active la config et redémarre Nginx :**

```bash
sudo ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 3. Installer les services (WordPress, Dashy, Gitea)

- **WordPress** (sur 192.168.30.20) :  
  Utilise `docker`, `docker-compose` ou installation classique LAMP selon ton choix.
- **Dashy** (sur 192.168.30.90:8080) :  
  [https://dashy.to/docs/](https://dashy.to/docs/)
- **Gitea** (sur 192.168.30.90:3000) :  
  [https://docs.gitea.com/installation](https://docs.gitea.com/installation)

(Tu peux me préciser si tu veux les étapes pour installer l’un de ces services !)

---

## 4. Tester

- Sur un client, mets 192.168.30.10 comme DNS.
- Ping `wordpress.auth.local`, il doit répondre 192.168.30.100.
- Ouvre `http://wordpress.auth.local` dans un navigateur, ça doit t'afficher ton site WordPress (ou l'accueil du service, selon ce qui tourne).

---

Dis-moi sur quelle(s) partie(s) tu veux plus de détails ou si tu veux un script pour automatiser !

Si tu veux un exemple de fichier précis ou si tu as une distribution différente, précise-la !
Si tu veux un script qui automatise tout ou un exemple de Dockerfile/compose, demande-moi !

