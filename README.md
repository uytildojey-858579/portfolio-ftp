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

Si tu veux un script qui automatise tout ou un exemple de Dockerfile/compose, demande-moi !

