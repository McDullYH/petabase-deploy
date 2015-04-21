#!/bin/bash

real_usr="`whoami`"
check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 0
fi


#if [ -e "./ssh_config" ];then
#  SSH_ARGS="-F ./ssh_config"
#fi

# change to esensoft-petabase dir
SCRIPT_DIR="$(cd "$( dirname "$0")" && pwd)"
ESEN_DIR=${SCRIPT_DIR}
ESEN_PETA=${ESEN_DIR%/*}
NAMENODE_SOFT_DIR=$ESEN_PETA/namenode-software
DATANODE_SOFT_DIR=$ESEN_PETA/datanode-software
SEC_NAMENODE_SOFT_DIR=$ESEN_PETA/sec-namenode-software
COMMON_SOFT_DIR=$ESEN_PETA/common-software
NESS_SOFT_DIR=$ESEN_PETA/ness-software
EXT_SOFT_DIR=$ESEN_PETA/ext-software

# import temp variable
source ./deploy_config.sh

# may no need
report_failure_and_exit()
{
 echo "${1}"
 exit 0
}


# do it when successfully install, forbid to reinstall
mark_uninstall()
{
  # TODO finishit later
  return 1
}


hostlist=()
secondnode=""


usage(){
  cat <<EOF
  usage $0:[-n|-s|-?] [optional args]
  -n   petabase slaves hostname list
  -s   secondarynamenode hostname
  -?   help message
  
  e.g. $0 -n bigdata2,bigdata3 -s bigdata2
  e.g. $0 -n esen-petabase-234,esen-petabase-235 -s esen-petabase-234
EOF
exit 1
}

while getopts "n:s:?:" options;do
  case $options in
    n ) IFS=',' hostlist=($OPTARG);;
    s ) secondnode="$OPTARG";;
    \? ) usage;;
    * ) usage;;
  esac
done;

delete_group-user_namenode()
{
  userdel -r $PETA_USER 1>/dev/null 2>&1
  groupdel $PETA_GRP 1>/dev/null 2>&1
}

delete_group-user_datanode()
{
  for host in ${hostlist[@]}; do
    ssh  $host "userdel -r $PETA_USER" 1>/dev/null 2>&1
    ssh  $host "groupdel $PETA_GRP" 1>/dev/null 2>&1
  done
}


uninstall_soft_namenode()
{
  echo "uninstall jdk on $MASTER_HOST"
  rm -rf /usr/java
  sed -i '/export JAVA_HOME=/'d /etc/profile
  sed -i '/export JRE_HOME=/'d /etc/profile
  sed -i '/export CLASSPATH=/'d /etc/profile
  sed -i '/export PATH=/'d /etc/profile

  echo "uninstall software on $MASTER_HOST"

  for rpm_file in $NAMENODE_SOFT_DIR/*.rpm
  do
    check_and_uninstall_local $rpm_file
  done

  for rpm_file in $COMMON_SOFT_DIR/*.rpm
  do
    check_and_uninstall_local $rpm_file
  done


}

uninstall_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    echo "uninstall jdk on $host"
    ssh  $host "rm -rf /usr/java"
    ssh  $host "sed -i '/export JAVA_HOME=/'d /etc/profile"
    ssh  $host "sed -i '/export JRE_HOME=/'d /etc/profile"
    ssh  $host "sed -i '/export CLASSPATH=/'d /etc/profile" 
    ssh  $host "sed -i '/export PATH=/'d /etc/profile" 

    for rpm_file in $DATANODE_SOFT_DIR/*.rpm
    do
      check_and_uninstall_remote $host $rpm_file
    done

    for rpm_file in $COMMON_SOFT_DIR/*.rpm
    do 
      check_and_uninstall_remote $host $rpm_file
    done
  done

  uninstall_cdh_secondarynamenode
}


uninstall_cdh_secondarynamenode()
{

  for rpm_file in $SEC_NAMENODE_SOFT_DIR/*.rpm
    do
      check_and_uninstall_remote $secondnode $rpm_file
    done
}


######################################################################################

if [ $hostlist ]; then
  iecho "`date +%Y-%m-%d-%T` uninstall begin"
  iecho "delete user and group"
  delete_group-user_namenode
  delete_group-user_datanode
  iecho "uninstall software"
  uninstall_soft_namenode
  uninstall_soft_datanodes
  iecho "`date +%Y-%m-%d-%T` finish"
else
  iecho "no slaves,finish"
fi
