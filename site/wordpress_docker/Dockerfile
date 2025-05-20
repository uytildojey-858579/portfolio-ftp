FROM php:7.1-apache

# Activer mod_rewrite
RUN a2enmod rewrite

# Installer les dépendances système nécessaires pour les extensions PHP
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    unzip \
    curl \
    && docker-php-ext-install mysqli curl xml mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copier WordPress
COPY ./wordpress /var/www/html

# Télécharger et installer phpMyAdmin 4.8.1
RUN curl -o /tmp/phpmyadmin.zip -L https://files.phpmyadmin.net/phpMyAdmin/4.8.1/phpMyAdmin-4.8.1-all-languages.zip \
    && unzip /tmp/phpmyadmin.zip -d /tmp/ \
    && mv /tmp/phpMyAdmin-4.8.1-all-languages /var/www/html/phpmyadmin \
    && rm /tmp/phpmyadmin.zip

# Donner les droits à Apache
RUN chown -R www-data:www-data /var/www/html
