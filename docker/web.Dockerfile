FROM nginx:latest

COPY ./nginx/*.conf /etc/nginx/

WORKDIR /var/www/example.com