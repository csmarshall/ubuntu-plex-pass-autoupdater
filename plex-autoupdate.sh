#!/bin/bash
# Script to check for a plex pass update and update or notify

#Timestamp Function for logging info
ts () {
        echo -n "$(date +'%F-%R:%S ')"
        echo $*
}

clean_up () {
    local EXIT_CODE=${1} 
    if [[ -e "${DPKG_FILE}" ]] ; then
        ts "Removing ${DPKG_FILE}"
        rm ${DPKG_FILE}
    fi
    ts "All Done"
    exit ${EXIT_CODE}
}

trap clean_up SIGHUP SIGINT SIGTERM

usage () {
  echo "$0 PLEX_PASS_TOKEN"
  exit 1
}

check_exit () { 
  local OPERATION=${1}
  local EXIT_CODE=${2}
  if [[ "${OPERATION}" -ne "0" ]] ; then
    ts "Operation ${OPERATION} of ${FUNCNAME[1]} failed with exit code: ${EXIT_CODE}, exiting ${EXIT_CODE}"
    return ${RESULT_CODE}
  fi
}

determine_system () {
  export HW_PLATFORM=$(/bin/uname -i)
  ts "Hardware platform detected \"${HW_PLATFORM}\""
}

determine_installed_version () {
  INSTALLED_PLEX_VERSION=$(dpkg -l plexmediaserver 2>/dev/null | grep plexmediaserver  | awk '{print $3}')
  if [ -z "${INSTALLED_PLEX_VERSION}" ] ; then
    ts "plexmediaserver is not installed according to dpkg"
    determine_available_version
    ts "Download plex from this URL: ${AVAILABLE_PLEX_URL}"
    local DPKG_FILE="/tmp/$(basename ${AVAILABLE_PLEX_URL})"
    echo "curl -o ${DPKG_FILE} ${AVAILABLE_PLEX_URL} && sudo dpkg -i ${DPKG_FILE} \; rm ${DPKG_FILE}"
    clean_up 1
  else 
    ts "plexmediaserver version ${INSTALLED_PLEX_VERSION} installed"
  fi
}

determine_available_version () {
  local HW_PLATFORM="${1}"
  local PLEX_PASS_TOKEN="${2}"
  ts "Querying plex.tv for current plexmediaserver URL"
  export AVAILABLE_PLEX_URL=$(curl "https://plex.tv/downloads/latest/1?channel=8&build=linux-ubuntu-${HW_PLATFORM}&distro=ubuntu&X-Plex-Token=${PLEX_PASS_TOKEN}" 2>/dev/null | sed -e 's/^.*href="//' -e 's/".*$//g')
  export AVAILABLE_PLEX_VERSION=$(basename ${AVAILABLE_PLEX_URL} | awk -F_ '{print $2}')
  ts "plexmediaserver version ${AVAILABLE_PLEX_VERSION} available from plex.tv"
}

should_i_upgrade () {
  local INSTALLED_PLEX_VERSION=${1}
  local AVAILABLE_PLEX_VERSION=${2}
  INSTALLED_PLEX_INT=$(echo ${INSTALLED_PLEX_VERSION} | sed -e 's/[-\.]//g') 
  AVAILABLE_PLEX_INT=$(echo ${AVAILABLE_PLEX_VERSION} | sed -e 's/[-\.]//g') 
  if [[ "${AVAILABLE_PLEX_INT}" -gt "${INSTALLED_PLEX_INT}" ]] ; then
    ts "Available version: ${AVAILABLE_PLEX_VERSION} newer than installed: ${INSTALLED_PLEX_VERSION}, should upgrade!"
  elif [[ "${AVAILABLE_PLEX_INT}" -eq "${INSTALLED_PLEX_INT}" ]] ; then
    ts "Available version: ${AVAILABLE_PLEX_VERSION} is already installed: ${INSTALLED_PLEX_VERSION}"
    clean_up 0
  fi 
}

download_and_install () {
  local AVAILABLE_PLEX_URL=${1}
  export DPKG_FILE="/tmp/$(basename ${AVAILABLE_PLEX_URL})"
  ts "Downloading ${AVAILABLE_PLEX_URL} to ${DPKG_FILE} "
  curl -o ${DPKG_FILE} ${AVAILABLE_PLEX_URL} 
  ts "Installing ${DPKG_FILE}"
  dpkg -i ${DPKG_FILE} ; check_exit "install" ${?}
  if [[ "${?}" -eq "0" ]]; then
    determine_installed_version
  else
    clean_up 1
  fi
  rm -v ${DPKG_FILE}
}

PLEX_PASS_TOKEN=${1}

if [ -z "${PLEX_PASS_TOKEN}" ] ; then
  ts "Script assumes plex pass membership"
  usage;
fi

### Start
ts "Start ${0}"

### System
determine_system

### Installed Version
determine_installed_version

### Available Version
determine_available_version ${HW_PLATFORM} ${PLEX_PASS_TOKEN}

### Should I upgrade?
should_i_upgrade "${INSTALLED_PLEX_VERSION}" "${AVAILABLE_PLEX_VERSION}"

### Upgrade
download_and_install ${AVAILABLE_PLEX_URL}

### 
clean_up 0

