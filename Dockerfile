# Stage 1: Install frontend dependencies and build JS and CSS
FROM kkarczmarczyk/node-yarn:latest AS yarn

WORKDIR /var/www/html

# Copy only the necessary files for yarn
COPY package.json yarn.lock /var/www/html/

RUN yarn install

# Copy the entire project for the build stage
COPY . /var/www/html/

# Run the build script
RUN mkdir -p /var/www/html/public/build && yarn run build

# Stage 2: Install PHP dependencies and configure Apache
FROM composer AS composer

WORKDIR /var/www/html

# Copy only the necessary files for composer
COPY composer.* /var/www/html/

# Allow symfony/flex plugin
RUN composer config --no-plugins allow-plugins.symfony\/flex true && \
    composer update

# Stage 3: Build actual image
FROM php:7.2-apache

WORKDIR /var/www/html

# Install required packages
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    curl git openssl \
    less vim wget unzip rsync git default-mysql-client \
    libcurl4-openssl-dev libfreetype6 libjpeg62-turbo libpng-dev libjpeg-dev libxml2-dev libxpm4 \
    libicu-dev coreutils openssh-client libsqlite3-dev && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg-dir=/usr/local/ && \
    docker-php-ext-install -j$(nproc) iconv intl pdo_sqlite curl json xml mbstring zip bcmath soap pdo_mysql gd

# Enable Apache modules
RUN /usr/sbin/a2enmod rewrite headers expires

# Configure Apache
COPY ./container/apache.conf /etc/apache2/sites-available/000-default.conf

# Copy needed files from build containers
COPY --from=yarn /var/www/html/public/build/ /var/www/html/public/build/
COPY --from=composer /var/www/html/vendor/ /var/www/html/vendor/

# Ensure that cache, log, and session directories are writable
RUN mkdir -p /var/www/html/var && \
    chown -R www-data:www-data /var/www/html/var

# Expose port 80 for Apache
EXPOSE 80

# Start Apache in the foreground
CMD ["apache2-foreground"]
