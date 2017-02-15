#!/bin/bash
function usage()
 {
    echo "INFO:"
    echo "Usage: deploy.sh [storage-account-name] [storage-account-key] [ansible user]"
}

error_log()
{
    if [ "$?" != "0" ]; then
        log "$1"
        log "Deployment ends with an error" "1"
        exit 1
    fi
}

function log()
{
  mess="$(hostname): $1"
  logger -t "${BASH_SCRIPT}" "${mess}"
}

function ssh_config()
{
  log "Configure ssh..."
  log "Create ssh configuration for ${ANSIBLE_USER}"

  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "${ANSIBLE_USER}"  >> "/home/${ANSIBLE_USER}/.ssh/config"

  error_log "Unable to create ssh config file for user ${ANSIBLE_USER}"
}

function install_ansible()
{
    log "Install software-properties-common ..."
    until apt-get --yes install software-properties-common
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install ppa:ansible/ansible ..."
    until apt-add-repository --yes ppa:ansible/ansible
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Update System ..."
    until apt-get --yes update
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install Ansible ..."
    until apt-get --yes install ansible
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install sshpass"
    until apt-get --yes install sshpass
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install git ..."
    until apt-get --yes install git
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install unzip ..."
    until apt-get --yes install unzip
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install pip ..."
    until apt-get --yes install python-pip
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done
}

function fix_etc_hosts()
{
  log "Add hostame and ip in hosts file ..."
  IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
  HOST=$(hostname)
  echo "${IP}" "${HOST}" >> "${HOST_FILE}"
}

function configure_ansible()
{
  log "Generate ansible files..."
  rm -rf /etc/ansible
  error_log "Unable to remove /etc/ansible directory"
  mkdir -p /etc/ansible
  error_log "Unable to create /etc/ansible directory"

  # Remove Deprecation warning
  printf "[defaults]\ndeprecation_warnings = False\nhost_key_checking = False\nexecutable = /bin/bash\n\n"    >>  "${ANSIBLE_CONFIG_FILE}"

  # Shorten the ControlPath to avoid errors with long host names , long user names or deeply nested home directories
  echo  $'[ssh_connection]\ncontrol_path = ~/.ssh/ansible-%%h-%%r'                    >> "${ANSIBLE_CONFIG_FILE}"
  # fix ansible bug
  printf "\npipelining = True\n"                                                      >> "${ANSIBLE_CONFIG_FILE}"


}

function get_roles()
{
  ansible-galaxy install -f -r install_roles.yml
  error_log "Can't get roles from Galaxy'"
}

function configure_deployment()
{
  mkdir -p vars
  error_log "Fail to create vars directory"
  mkdir -p group_vars
  error_log "Fail to create group_vars  directory"
  mv main.yml vars/main.yml
  mv mysql_default.yml vars/mysql_default.yml
  error_log "Fail to move mysql default vars file to directory vars"
}

function create_extra_vars()
{
  d="$(date -u +%Y%m%d%H%M%SZ)"
  printf "{\n  \"ansistrano_release_version\": \"%s\",\n" "${d}"            > "${EXTRA_VARS}"
  printf "  \"prestashop_lb_name\": \"%s\",\n" "${lbName}"                 >> "${EXTRA_VARS}"
  printf "  \"gabarit\": \"%s\",\n" "${gabarit}"                           >> "${EXTRA_VARS}"
  printf "  \"prestashop_firstname\": \"%s\",\n" "${prestashop_firstname}" >> "${EXTRA_VARS}"
  printf "  \"prestashop_lastname\": \"%s\",\n" "${prestashop_lastname}"   >> "${EXTRA_VARS}"
  printf "  \"prestashop_email\": \"%s\",\n" "${prestashop_email}"         >> "${EXTRA_VARS}"
  printf "  \"prestashop_password\": \"%s\"\n}" "${prestashop_password}"   >> "${EXTRA_VARS}"
}

function deploy_prestashop()
{
  ansible-playbook deploy.yml -i "localhost," --connection=local --extra-vars "@${EXTRA_VARS}" > /tmp/ansible-prestashop.log 2>&1
  error_log "Fail to deploy front cluster !"
}

log "Execution of Install Script from CustomScript ..."

## Variables

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

log "CustomScript Directory is ${CWD}"

BASH_SCRIPT="${0}"
ANSIBLE_USER="${1}"
lbName="${2}"
prestashop_password="${3:-prestashop}"
prestashop_firstname="${4}"
prestashop_lastname="${5}"
prestashop_email="${6}"
gabarit=$(echo "${7}" | cut -f2 -d_)

case "${gabarit}" in
    ds1|ds2|ds3|ds4|ds11|ds12|ds13|ds14|d15) isok=true;;
    *)             gabarit="ds1";;
esac

HOST_FILE="/etc/hosts"
ANSIBLE_CONFIG_FILE="/etc/ansible/ansible.cfg"

EXTRA_VARS="${CWD}/extra_vars.json"

## main
fix_etc_hosts
ssh_config
install_ansible
configure_ansible
get_roles
configure_deployment
create_extra_vars
deploy_prestashop

log "Success : End of Execution of Install Script from CustomScript"

exit 0
