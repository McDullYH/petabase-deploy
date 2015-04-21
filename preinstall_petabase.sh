#!/bin/bash
# 先安装MapReduce V1  后期 进行YARN的安装

real_usr="`whoami`"
check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 0
fi



NAMENODE_FILE_LIST="nn_fl"
DATANODE_FILE_LIST="dn_fl"
SECNAMENODE_FILE_LIST="snn_fl"
COMMON_FILE_LIST="common_fl"
EXT_FILE_LIST="ext_fl"
NESS_FILE_LIST="ness_fl"
MYSQL_FILE_LIST="mysql_fl"

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
MYSQL_SOFT_DIR=$ESEN_PETA/mysql-software

# import temp variable
source ./deploy_config.sh


hostlist=()
secondnode=""


usage(){
  cat <<EOF
  usage $0:[-n|-s|-?] [optional args]
  -n   petabase slaves hostname list
  -s   secondarynamenode hostname
  -?   help message
  
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

# use MD5 to check the file will be more simple and better
check_file()
{
#  if [-f $NAMENODE_FILE_LIST ];then
#    while read LINE
#    do
#      if [-f $NAMENODE_SOFT_DIR/$LINE ];then
#        echo "$LINE exists"
#      else
#        echo "$LINE not exist"
#      fi
#    done  < $NAMENODE_FILE_LIST
#  else
#    echo "$NAMENODE_FILE_LIST 不存在，无法验证文件完整性"
#  fi
#  if [-f $DATANODE_FILE_LIST ];then
#    while read LINE
#    do
#      if [-f $DATANODE_SOFT_DIR/$LINE ];then
#        echo "$LINE exists"
#      else
#        echo "$LINE not exist"
#      fi
#    done  < $DATANODE_FILE_LIST
#  else
#    echo "$DATANODE_FILE_LIST 不存在，无法验证文件完整性"
#  fi
#  if [-f $SECNAMENODE_FILE_LIST ];then
#    while read LINE
#    do
#      if [-f $SEC_NAMENODE_DIR/$LINE ];then
#        echo "$LINE exists"
#      else
#        echo "$LINE not exist"
#      fi
#    done  < $SECNAMENODE_FILE_LIST
#  else
#    echo "$SECNAMENODE_FILE_LIST 不存在，无法验证文件完整性"
#  fi
#  return 1
return 1;
}



copy_esen_software()
{
for host in ${hostlist[@]}; do
  echo "Copying software to $host"
  ssh ${SSH_ARGS} $host "mkdir -p $ESEN_PETA/" 1>/dev/null 2>&1
  rsync -avzu --progress $COMMON_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $COMMON_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $DATANODE_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $DATANODE_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $SEC_NAMENODE_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $SEC_NAMENODE_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $NESS_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $NESS_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

done
}


install_necessary_soft_namenode()
{

  echo "[Log] preinstall begin on $MASTER_HOST"

  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
    check_and_install_local $rpm_file
    if [ $? -ne 0];then
      return 1
    fi
  done
}


install_necessary_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    echo "[Log] $host 启动预安装"

  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
    check_and_install_remote $host $rpm_file
    if [ $? -ne 0];then
      return 1
    fi
    done
 done

}

uninstall_necessary_soft_namenode()
{
  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
      pkgname=`basename $rpm_file .rpm`
      echo "uninstalling $pkgname"
      rpm -e --nodeps ${pkgname} 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall ${pkgname} on $MASTER_HOST"
      fi
  done
}


uninstall_necessary_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    for rpm_file in $NESS_SOFT_DIR/*.rpm
      do 
        pkgname=`basename $rpm_file .rpm`
        echo "uninstalling $pkgname on $host"
        ssh   $host    "rpm -e --nodeps ${pkgname} 1>/dev/null 2>&1"
        if [ $? -ne 0 ];then
          eecho "Unable to uninstall ${pkgname} to $host"
        fi
      done
  done

}



ssh_auth()
{
  ssh-keygen -t rsa;
  for host in ${hostlist[@]};do
    echo "auth for $host"
    ssh-copy-id $host
  done
}

install_mysql()
{

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-common-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-common to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi
      
  rpm -ivh --replacefiles $MYSQL_SOFT_DIR/mysql-community-libs-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-libs to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-client-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-client to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/perl-DBI-1.609-4.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-perl-DBI to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-server-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-server to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

}



configure_mysql()
{
  service mysqld start
  chkconfig mysqld on
  sleep 7
  /usr/bin/mysql_secure_installation

  # 注意 Disallow root login remotely? 选择 n

}

uninstall_mysql()
{
  rpm -e mysql-community-server-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-server to $MASTER_HOST"
      fi
  rpm -e mysql-community-client-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-client to $MASTER_HOST"
      fi
  rpm -e mysql-community-libs-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-libs to $MASTER_HOST"
      fi
  rpm -e mysql-community-common-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-common to $MASTER_HOST"
      fi
  rpm -e perl-DBI-1.609-4.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-perl-DBI to $MASTER_HOST"
      fi

  rm -f /etc/my.cnf
}


#TODO 目前仅仅禁用本机的防火墙和selinux,没有问题，若发现问题，再来定位
configure_iptables()
{
  service iptables stop;
  chkconfig iptables off;
}


configure_selinux()
{
  cp selinux_config /etc/selinux/config
  setenforce 0
}

#############################################################################

if [ $hostlist ]; then
  echo "`date +%Y-%m-%d-%T`开始预安装"

  #echo "检查文件完整性"
  #check_file

  iecho "配置SSH"
  ssh_auth

  iecho "正在拷贝组件到其他节点"
  copy_esen_software

  iecho "安装必要软件"
  install_necessary_soft_namenode
  if [ $? -ne 0];then
   eecho "主机上安装必要软件失败，退出"
   return 1
  fi

  install_necessary_soft_datanodes
  if [ $? -ne 0];then
   eecho "从机上安装必要软件失败，退出"
   return 1
  fi

  iecho "安装mysql server"
  install_mysql

  iecho "配置mysql"
  configure_mysql

  iecho "禁止iptables 启动"
  configure_iptables

  iecho "禁止selinux 启动"
  configure_selinux

  # for test script never use
  # uninstall_mysql
  ## uninstall_necessary_soft_namenode
  ## uninstall_necessary_soft_datanodes

  iecho "`date +%Y-%m-%d-%T` 完成"
else
  iecho "未输入datanode或者second-namenode"
fi
