#!/bin/bash
# Script to check for a plex pass update and update or notify

#Timestamp Function for logging info
ts () {
            echo -n "$(date +'%F-%R:%S ')"
                    echo $*
}

usage () {
      echo "$0 PLEX_PASS_TOKEN"
        exit 1
}

determine_system () {
      export HW_PLATFORM=$(/bin/uname -i)
        ts "Hardware platform detected \"${HW_PLATFORM}\""
}

determine_installed_plexmediaserver () {
      ts "Querying dpkg for installed plexmediaserver version"
        local INSTALLED_PLEX_VERSION=$(dpkg -l plexmediaserver 2>/dev/null | grep plexmediaserver  | awk '{print $3}')
          if [ -z "${INSTALLED_PLEX_VERSION}" ] ; then
                  ts "plexmediaserver is not installed according to dpkg, investigate...exit 1"
                      exit 1
                        else 
                                ts "plexmediaserver version ${INSTALLED_PLEX_VERSION} currently installed"
                                  fi
                                    export INSTALLED_PLEX_VERSION=$(echo ${INSTALLED_PLEX_VERSION} | sed -e 's/[-\.]//g') 
}

determine_plex_url () {
      local ${HW_PLATFORM}=${1}
        local ${PLEX_PASS_TOKEN}=${2}
          ts "Querying plex.tv for current plexmediaserver URL"
            export AVAILABLE_PLEX_URL=$(curl 'https://plex.tv/downloads/latest/1?channel=8&build=linux-ubuntu-${HW_PLATFORM}&distro=ubuntu&X-Plex-Token=${PLEX_PASS_TOKEN}' | sed -e 's/^.*href="//' -e 's/".*$//g')
}

determine_available_plexmediaserver () {
      local AVAILABLE_PLEX_URL=${1}
        local AVAILABLE_PLEX_VERSION=$(basename ${AVAILABLE_PLEX_URL} | awk -F_ '{print $2}')
          ts "plexmediaserver version ${AVAILABLE_PLEX_VERSION} available from plex.tv"
            export AVAILABLE_PLEX_VERSION=$(echo ${AVAILABLE_PLEX_VERSION} | sed -e 's/[-\.]//g')
}

should_upgrade () {
      if (( ${AVAILABLE_PLEX_VERSION} > ${INSTALLED_PLEX_VERSION})) ; then
              ts "AVAILABLE_PLEX_VERSION: ${AVAILABLE_PLEX_VERSION} newer than INSTALLED_PLEX_VERSION: ${INSTALLED_PLEX_VERSION}"
                elif (( ${AVAILABLE_PLEX_VERSION} == ${INSTALLED_PLEX_VERSION})); then
                    ts "AVAILABLE_PLEX_VERSION: ${AVAILABLE_PLEX_VERSION} is already INSTALLED_PLEX_VERSION: ${INSTALLED_PLEX_VERSION}"
                        exit 0
                          fi 
}

download_and_install () {
      local AVAILABLE_PLEX_URL=${1}
        DPKG_FILE="/tmp/$(basename ${AVAILABLE_PLEX_URL})"
          ts "Downloading ${AVAILABLE_PLEX_URL} to ${DPKG_FILE} "
            curl -o ${DPKG_FILE} ${AVAILABLE_PLEX_URL}
              ts "Installing ${DPKG_FILE}"
                dpkg -i ${DPKG_FILE}
                  if [[ "${?}" -eq "0" ]]; then
                          determine_installed_plexmediaserver
                              ts "plexmediaserver version ${INSTALLED_PLEX_VERSION} now installed"
                                else
                                        ts "plexmediaserver dpkg install failed"
                                          fi
                                            rm -v ${DPKG_FILE}
}

PLEX_PASS_TOKEN=${1}

if [ -z "${PLEX_PASS_TOKEN}" ] ; then
      ts "Script assumes plex pass membership"
        usage;
        fi

### Start
ts "Start ${0} ${*}"

### System
ts "Determining system"
determine_system

### Installed Version
ts "Determining installed plexmediaserver"
determine_installed_plexmediaserver

### Available Version
ts "Determining available plexmediaserver" 
determine_plex_url ${HW_PLATFORM} ${PLEX_PASS_TOKEN}
determine_available_plexmediaserver ${AVAILABLE_PLEX_URL}

### Should I upgrade?
should_upgrade

### Upgrade
download_and_install ${AVAILABLE_PLEX_URL}

### All done
ts "Done"
