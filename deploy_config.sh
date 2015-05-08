#!/bin/bash

# shell 中 返回 0 表示成功 1表示失败
# 使用alias简化命令  注意引号，一般都是单引号


#java_main=/usr/java
#java_name=jdk1.7.0_45
#java_dir=$java_main/$java_name
# 最后必须没有斜杠 '/'
java_dir=/usr/java/default

PETA_USER="petabase"
PETA_GRP="petabase"
MASTER_HOST="`hostname`"


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
MYSQL_SOFT_DIR=$ESEN_PETA/mysql-software


# 必要的依赖软件比较特殊，
# 特殊1:jdk，在使用rpm -q 查找的时候不能带版本号查找，导致即使安装了却(使用带版本号的命令)检查不到，而安装却会失败
# 特殊2:openssl，CentOS yum update之后安装了更新的openssl，估计以后会有更新的，所以查找的时候也不应该带版本号
# 所以，在这里必须使用软件列表名的方式来判断软件的安装情况

declare -A COMMON_SOFT_DICT
declare -A NAMENODE_SOFT_DICT
declare -A DATANODE_SOFT_DICT
declare -A SEC_NAMENODE_SOFT_DICT
declare -A NESS_SOFT_DICT
declare -A EXT_SOFT_DICT
declare -A MYSQL_SOFT_DICT

construct_soft_dict()
{

  while read LINE
  do
  key=$LINE
  read LINE
  COMMON_SOFT_DICT[${key}]=$LINE
  done < $COMMON_SOFT_DIR/rpm.list

  while read LINE
  do
  key=$LINE
  read LINE
  NESS_SOFT_DICT[${key}]=$LINE
  done < $NESS_SOFT_DIR/rpm.list

  while read LINE
  do
  key=$LINE
  read LINE
  NAMENODE_SOFT_DICT[${key}]=$LINE
  done < $NAMENODE_SOFT_DIR/rpm.list

  while read LINE
  do
  key=$LINE
  read LINE
  DATANODE_SOFT_DICT[${key}]=$LINE
  done < $DATANODE_SOFT_DIR/rpm.list

  while read LINE
  do
  key=$LINE
  read LINE
  SEC_NAMENODE_SOFT_DICT[${key}]=$LINE
  done < $SEC_NAMENODE_SOFT_DIR/rpm.list

  while read LINE
  do
  key=$LINE
  read LINE
  EXT_SOFT_DICT[${key}]=$LINE
  done < $EXT_SOFT_DIR/rpm.list
}


# this is just for test
show_soft_dict()
{
  for key in ${!COMMON_SOFT_DICT[@]};do
    echo "key is ${key} and value is ${COMMON_SOFT_DICT[${key}]}"
  done

  for key in ${!NESS_SOFT_DICT[@]};do
    echo "key is ${key} and value is ${NESS_SOFT_DICT[${key}]}"
  done
}



eecho()
{
  echo -e  "\033[0;31;1m$@ \033[0m"
}

iecho()
{
  echo -e  "\033[0;32;1m$@ \033[0m"
}

wecho()
{
  echo -e  "\033[0;33;1m$@ \033[0m"
}

# may no need
report_failure_and_exit()
{
 echo "${1}"
 exit 0
}


install_soft_local()
{
  if [ $# -ne 1 ] ; then
    echo "必须为 install_soft_local 指定一个参数"
    return 1
  fi
  echo "正在安装${1} ..."
  rpm -Uvh --nodeps ${1}
  # -Uvh is better than -ivh if the software's old version is installed
}


install_soft_remote()
{
  if [ $# -ne 2 ] ; then
    echo "必须为 install_soft_remote 指定2个参数"
    return 1
  fi
  echo "正在${1}上安装${2} ..."
  ssh ${1} "rpm -Uvh --nodeps ${2}"
}

uninstall_soft_local()
{
  if [ $# -ne 1 ] ; then
    echo "必须为 uninstall_soft_local 指定一个参数"
    return 1
  fi
  echo "正在卸载${1} ..."
  rpm -e --nodeps ${1}
}

uninstall_soft_remote()
{
  if [ $# -ne 2 ] ; then
    echo "必须为 uninstall_soft_remote 指定2个参数"
    return 1
  fi
  echo "正在${1}上卸载${2} ..."
  ssh ${1} "rpm -e --nodeps ${2}"
}



# 0 for installed and 1 for not install
check_install_local()
{
  if [ $# -ne 1 ] ; then
    echo "必须为 install_soft_local 指定一个参数"
    return -1
  fi
  echo "正在检查${1}的安装情况"
  rpm -q ${1} 1>/dev/null 2>&1
}



check_install_remote()
{
  if [ $# -ne 2 ] ; then
    echo "必须为 check_install_remote 指定2个参数"
    return -1
  fi
  echo "正在检查${1}上${2}的安装情况"
  ssh ${1} rpm -q ${2}   1>/dev/null  2>&1
}


# 上面2个函数仅仅只检查或者只安装，实际过程中应该检查并安装
check_and_install_local()
{

 pkgname=`basename $1 .rpm`
 check_install_local $pkgname
 if [ $? -eq 0 ]; then
   echo "本机已经安装${1}，不需要再次安装"
   return 0
 fi

 install_soft_local ${1}
 if [ $? -ne 0 ]; then
   eecho "在本机安装${1}失败，请检查相关日志"
   return 1
 else
   return 0
 fi
}

check_and_install_remote()
{
 pkgname=`basename $2 .rpm`
 check_install_remote $1 $pkgname
 if [ $? -eq 0 ]; then
   echo "${1}已经安装${pkgname}，不需要再次安装"
   return 1
 fi

 install_soft_remote $@
 if [ $? -ne 0 ]; then
   eecho "在${1}安装${pkgname}失败，请检查相关日志"
   return 1
 else
   return 0
 fi
}


check_and_uninstall_local()
{
 pkgname=`basename $1 .rpm`
 check_install_local $pkgname
 if [ $? -eq 1 ]; then
   echo "本机没有安装${pkgname}，不需要卸载"
   return 0
 fi

 uninstall_soft_local $pkgname
 if [ $? -ne 0 ]; then
   eecho "在本机卸载${pkgname}失败，请检查相关日志"
   return 1
 else
   return 0
 fi
}

check_and_uninstall_remote()
{

 pkgname=`basename $2 .rpm`
 check_install_remote $1 $pkgname
 if [ $? -eq 1 ]; then
   echo "${1}没有安装${pkgname}，不需要卸载"
   return 0
 fi

 uninstall_soft_remote $1 $pkgname
 if [ $? -ne 0 ]; then
   eecho "在${1}卸载${pkgname}失败，请检查相关日志"
   return 1
 else
   return 0
 fi
}



# 简单定义一个ssh，只需修改esen_ssh_arg，便可以在所有的ssh命令中使用该参数
# 自定义的依然可以简单的使用ssh
esen-ssh()
{
 esen_ssh_arg=""
 ssh $esen_ssh_arg "$@"
}

# construct in this file
construct_soft_dict
