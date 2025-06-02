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
Bien sûr ! Voici les grandes étapes pour installer et configurer un serveur DNS BIND sur une nouvelle machine afin qu’il serve de DNS pour ton site :

---

## 1. Installer BIND

Sur une machine Linux (Debian/Ubuntu) :
```bash
sudo apt update
sudo apt install bind9 bind9utils bind9-doc
```

---

## 2. Configurer les fichiers BIND

### a. Fichier de configuration principal

- Le fichier principal de BIND est généralement `/etc/bind/named.conf` (Debian/Ubuntu) ou `/etc/named.conf` (CentOS).
- Ce fichier inclut les zones à servir.

### b. Définir la zone pour ton site

Ajoute dans le fichier de configuration :

```conf
zone "ton-domaine.com" {
    type master;
    file "/etc/bind/db.ton-domaine.com";
};
```
Remplace `ton-domaine.com` par ton vrai nom de domaine.

---

## 3. Créer le fichier de zone

Crée le fichier `/etc/bind/db.ton-domaine.com` :

```bash
sudo cp /etc/bind/db.local /etc/bind/db.ton-domaine.com
sudo nano /etc/bind/db.ton-domaine.com
```

Exemple de contenu de base :

```
$TTL    86400
@       IN      SOA     ns1.ton-domaine.com. admin.ton-domaine.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         86400 )        ; Negative Cache TTL

; Name servers
        IN      NS      ns1.ton-domaine.com.

; A records
@       IN      A       IP_DE_TA_MACHINE_WEB
ns1     IN      A       IP_DE_TA_MACHINE_DNS

; CNAME, MX, etc. à ajouter au besoin
```

Remplace les IPs et noms par les tiens.

---

## 4. Configurer les accès réseau

- Ouvre le port 53 en TCP et UDP sur le pare-feu.
- Exemple (ufw sur Ubuntu) :
```bash
sudo ufw allow 53
```

---

## 5. Tester la configuration

Vérifie la syntaxe :
```bash
sudo named-checkconf
sudo named-checkzone ton-domaine.com /etc/bind/db.ton-domaine.com
```

Redémarre BIND :
```bash
sudo systemctl restart bind9
```

---

## 6. Tester le serveur DNS

Depuis une autre machine :
```bash
dig @IP_DE_TA_MACHINE_DNS ton-domaine.com
```

---

## 7. Mettre à jour les enregistrements du domaine

Chez ton registrar (où tu as acheté ton domaine), mets à jour les serveurs DNS (nameservers) pour pointer vers l’IP de ta machine BIND.

---

### Résumé

1. Installe BIND sur la nouvelle machine.
2. Crée et configure la zone DNS pour ton domaine.
3. Ouvre le port 53 sur le pare-feu.
4. Redémarre BIND et teste ta config.
5. Mets à jour ton registrar pour utiliser ton nouveau DNS.

Si tu veux un exemple de fichier précis ou si tu as une distribution différente, précise-la !
Si tu veux un script qui automatise tout ou un exemple de Dockerfile/compose, demande-moi !

