#!/bin/bash

if [ "$(id -u)" != 0 ]
then
  echo "Root permissions required" >&2
  exit 1
fi

RED='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

certificate=""

echo $'Creating deploy files.\n'

set_domain() {
  read -p $"Print the domain (localhost): " domain

  if [ "$domain" = "" ]
    then
      domain="localhost"
      echo "domain is $domain"
  fi
}

file_exists() {
  read -p "$1 already exists, continue? (y/yes or n/no): " continue

  if [ $continue = "yes" -o $continue = "y" ]
  then
    $2
  elif [ $continue = "no" -o $continue = "n" ]
  then
    echo "Program is finished."
    exit 0;
  else
    echo "Invalid option, try again."
    file_exists "$1" "$2"
  fi
}

set_certificate() {
  read -p "Create certificate? (y/yes or n/no): " certificate

  if [ $certificate = "yes" -o $certificate = "y" ]
  then
    set_domain
    certbot_run "dry"
    certbot_run
  elif [ $certificate = "no" -o $certificate = "n" ]
  then
    echo "Ok."
  else
    echo "Invalid option, try again."
    set_certificate
  fi
}

set_nginx() {
  nginxfile=$(curl https://raw.githubusercontent.com/aigen31/lemp-configs/main/php/example.com.conf)
  
  configpath=$PWD/docker/nginx/conf/$domain.conf

  replace() {
    replace=${nginxfile//example.com/$domain}
    echo "$replace" > "$configpath"
    chown -R 1000:1000 "$configpath"
    chmod 755 "$configpath"
  }

  if [ ! -f "$configpath" ]
  then
    replace
  else
    file_exists "$configpath" replace
  fi
}

compose_is_running() {
  containers_list=$(docker-compose ps -q)
  if [ "$containers_list" != "" ]
  then
    echo "docker-compose is running, stopping it..."
    docker-compose down
  fi
}

certbot_run() {
  compose_is_running
  if [ "$1" = "dry" ]
  then
    docker run -it --rm --name certbot \
      -v "$PWD/docker/letsencrypt:/etc/letsencrypt" \
      -v "$PWD/docker/letsencrypt:/var/lib/letsencrypt" \
      -p 80:80 \
      certbot/certbot certonly --standalone --dry-run -d $domain
  elif [ $# -gt 1 ]
  then
    echo "This function can't have more than one argument"
  else
    docker run -it --rm --name certbot \
      -v "$PWD/docker/letsencrypt:/etc/letsencrypt" \
      -v "$PWD/docker/letsencrypt:/var/lib/letsencrypt" \
      -p 80:80 \
      certbot/certbot certonly --standalone -d $domain
  fi
  chmod -R 755 $PWD/docker/letsencrypt
}

make_dir() {
  mkdir $PWD/docker/www/$domain
}

create_project() {
  set_domain
  set_nginx

  if [ ! -d "$PWD/docker/www/$domain" ]
  then
    make_dir
    chown -R www-data:www-data $PWD/docker/www/$domain
    chmod -R 775 $PWD/docker/www/$domain
  fi

  echo -e "${GREEN}Operation completed!${NC}"
}

PS3=$'\nSelect the project type: '

select number in "Create project" "Create the SSL certificate" "Exit"
do
  case $number in
    "Create project")
      create_project
      break
    ;;
    "Create the SSL certificate")
      set_certificate
      break
    ;;
    "Exit")
      exit 0
    ;;
    *) echo "Invalid option";;
  esac
done
