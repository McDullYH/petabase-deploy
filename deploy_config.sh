#!/bin/bash

# shell 中 返回 0 表示成功 1表示失败
# 使用alias简化命令  注意引号，一般都是单引号


java_main=/usr/java
java_name=jdk1.7.0_45
java_dir=$java_main/$java_name

PETA_USER="petabase"
PETA_GRP="petabase"
MASTER_HOST="`hostname`"

zoo_version="3.4.5+cdh5.3.0+81-1.cdh5.3.0.p0.36.el6.x86_64"
cdh_version="2.5.0+cdh5.3.0+781-1.cdh5.3.0.p0.54.el6.x86_64"
hive_version="0.13.1+cdh5.3.0+306-1.cdh5.3.0.p0.29.el6.noarch"
hbase_version="hbase-0.98.6+cdh5.3.0+73-1.cdh5.3.0.p0.25.el6.x86_64"
peta_version="2.1.0+cdh5.3.0-el6.x86_64"


eecho()
{
  echo -e  "\033[0;31;1m$@ \033[0m"
}

iecho()
{
  echo -e  "\033[0;32;1m$@ \033[0m"
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
  # -Uvh is better than -ivh if the software's old version is installed
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


check_install_local()
{
  if [ $# -ne 1 ] ; then
    echo "必须为 install_soft_local 指定一个参数"
    return 1
  fi
  echo "正在检查${1}的安装情况"
  rpm -q ${1}
}



check_install_remote()
{
  if [ $# -ne 2 ] ; then
    echo "必须为 install_soft_remote 指定2个参数"
    return 1
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

