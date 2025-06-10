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



## Securiser avec 443, pas testé :
Très bonne remarque !  
Voici un guide ultra précis, étape par étape, avec **emplacement des fichiers**, **commandes** et **sur quelle machine** il faut agir, pour sécuriser Nginx sur ton reverse proxy avec ta PKI “maison”.

## Résumé du flux

- **PKI (ex: 192.168.30.50 ou autre)** : Ne sert qu’à signer les CSR et stocker la clé de CA.
- **Reverse Proxy (Nginx, 192.168.30.100)** : Doit générer sa clé privée, son CSR, recevoir le .crt signé, et être configuré en HTTPS.
- **Clients** : Importent le certificat racine (ca_root.crt).

---

## 1. Sur la machine PKI (ex: 192.168.30.50)

### (Si non fait) Générer la CA

```bash
mkdir -p ~/pki/ca
cd ~/pki/ca
openssl genrsa -aes256 -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca_root.crt -subj "/C=FR/ST=France/O=MonOrg/CN=MonCA"
```

- **Fichiers importants** :
  - `~/pki/ca/ca.key` (clé privée CA, NE JAMAIS SORTIR de cette machine)
  - `~/pki/ca/ca_root.crt` (certificat racine, à distribuer partout où il faut faire confiance à la CA)

---

## 2. Sur le reverse proxy (Nginx, 192.168.30.100)

### Générer la clé privée et le CSR avec plusieurs SAN

**Fichier de configuration OpenSSL (ex: `/etc/nginx/ssl/openssl-san.cnf`) :**

```ini name=/etc/nginx/ssl/openssl-san.cnf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = FR
ST = France
L = Paris
O = MonOrg
CN = wordpress.auth.local

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = wordpress.auth.local
DNS.2 = gitea.auth.local
DNS.3 = dashy.auth.local
```

**Commandes pour générer la clé et le CSR :**
```bash
sudo mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

sudo openssl genrsa -out nginx.key 2048
sudo openssl req -new -key nginx.key -out nginx.csr -config openssl-san.cnf
```

- **À transférer sur la PKI** : `/etc/nginx/ssl/nginx.csr`
- **À garder** : `/etc/nginx/ssl/nginx.key` (ne sort PAS de cette machine)

---

## 3. Sur la PKI (machine CA, ex 192.168.30.50)

**Signer le CSR du reverse proxy**

```bash
cd ~/pki/ca
openssl x509 -req -in /chemin/vers/nginx.csr -CA ca_root.crt -CAkey ca.key -CAcreateserial -out nginx.crt -days 825 -sha256 -extfile /chemin/vers/openssl-san.cnf -extensions req_ext
```

- `/chemin/vers/nginx.csr` : récupéré depuis le reverse proxy
- `/chemin/vers/openssl-san.cnf` : tu peux copier le même fichier que sur le reverse proxy

**Produit** : `nginx.crt` à renvoyer sur le reverse proxy.

---

## 4. Sur le reverse proxy (Nginx, 192.168.30.100)

**Copie les fichiers :**
- `/etc/nginx/ssl/nginx.crt` : certificat signé reçu de la PKI
- `/etc/nginx/ssl/ca_root.crt` : certificat racine reçu de la PKI (pour la chaîne complète)

**Exemple de config Nginx pour HTTPS**

```nginx name=/etc/nginx/sites-available/proxy
# Redirige tout le HTTP vers HTTPS
server {
    listen 80;
    server_name wordpress.auth.local gitea.auth.local dashy.auth.local;
    return 301 https://$host$request_uri;
}

# Reverse proxy HTTPS pour tous les services
server {
    listen 443 ssl;
    server_name wordpress.auth.local gitea.auth.local dashy.auth.local;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_trusted_certificate /etc/nginx/ssl/ca_root.crt;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Accès à WordPress
    location / {
        if ($host = "wordpress.auth.local") {
            proxy_pass http://192.168.30.20:80;
        }
        if ($host = "gitea.auth.local") {
            proxy_pass http://192.168.30.90:3000;
        }
        if ($host = "dashy.auth.local") {
            proxy_pass http://192.168.30.90:8080;
        }
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
}
```

**Active la config et recharge Nginx**

```bash
sudo ln -sf /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 5. Sur chaque client (Windows, Linux, etc.)

**Importer** le certificat racine `ca_root.crt` pour éviter l’avertissement de navigateur.

- Sous Linux : 
  - `sudo cp ca_root.crt /usr/local/share/ca-certificates/monca.crt`
  - `sudo update-ca-certificates`
- Sous Windows : 
  - Double-clique → Installer en tant qu’Autorité de certification racine de confiance

---

## Résumé du “balade” de fichiers

- **La clé privée de la CA** : NE SORT JAMAIS de la PKI.
- **Le CSR** : généré sur le reverse proxy, envoyé à la PKI pour signature.
- **Le certificat signé** : renvoyé de la PKI vers le reverse proxy.
- **Le certificat racine** : copié sur chaque client et serveur web.
- **La clé privée du reverse proxy** : NE SORT JAMAIS du reverse proxy.

---

### Tu ne fais donc “balader” que :
- Le CSR (du reverse proxy → PKI)
- Le certificat signé (PKI → reverse proxy)
- Le ca_root.crt (PKI → reverse proxy + clients)

**Aucune clé privée ne doit jamais sortir de la machine qui l’a générée !**

---

Si tu veux un script pour automatiser tout ça ou un schéma, demande-moi !

