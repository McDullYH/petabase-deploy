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
LXML_SOFT_DIR=$ESEN_PETA/lxml-software

CONFIGURATION_DIR=$ESEN_PETA/sbin/configuration.ripe


# 依然是逗号号分割
HOST_INFO_FILE=$ESEN_PETA/sbin/host.info
DATANODES=""
SECONDARY_NAMENODE=""
SERVICE_LIST="zookeeper,hadoop,hive,petabase"


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
declare -A LXML_SOFT_DICT

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


  while read LINE
  do
  key=$LINE
  read LINE
  LXML_SOFT_DICT[${key}]=$LINE
  done < $LXML_SOFT_DIR/rpm.list
}



construct_host_info()
{
if [ ! -r ${HOST_INFO_FILE} ];then
  wecho "集群节点信息文件 ${HOST_INFO_FILE} 不存在"
  exit 1
fi
while read LINE
do
  if [ ${LINE}x = "second-name-node:"x ];then
  read LINE
  SECONDARY_NAMENODE=$LINE
  fi
  if [ ${LINE}x = "datanodes:"x ];then
  read LINE
  IFS=','; DATANODES=$LINE;
  fi
done  <${HOST_INFO_FILE}
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


show_deploy_operate()
{
  iecho "操作类型:	${1}"
  iecho "从机列表:	${2}"
  iecho "第二主机:	${3}"

  iecho "输入 'YES' 以确认"
  read  TOGO
  if [ ${TOGO}x = "YES"x ];then
    return 0;
  else
    iecho "操作取消"
    return 1;
  fi
}

show_service_operate()
{
  iecho "操作类型:		${1}"
  iecho "是否操作主机:		${2}"
  iecho "从机列表:		${3}"
  iecho "第二主机:		${4}"
  iecho "要控制的服务列表 	${5}"

  iecho "输入 'YES' 以确认"
  read  TOGO
  if [ ${TOGO}x = "YES"x ];then
    return 0;
  else
    iecho "操作取消"
    return 1;
  fi
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

# 第一次部署好之后会自动启动所有服务
start_zookeeper_local()
{
  service zookeeper-server start 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    eecho "本机 zookeeper-server 启动失败"
  else
    echo "本机 zookeeper-server 启动成功"
  fi
  return ${ret}
}

start_zookeeper_remote()
{
  ssh "${1}" "service zookeeper-server start"  1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    eecho  "${1} zookeeper-server 启动失败"
  else
    echo  "${1} zookeeper-server 启动成功"
  fi
  return ${ret}
}



# local 一般就是 namenode， 我们默认在本机上部署namenode，且在本机上面执行所有的脚本
start_hadoop_local()
{
  service hadoop-hdfs-namenode start 1>/dev/null 2>&1
  ret1=$?
  if [ ${ret1} -ne 0 ];then
    eecho "本机 hadoop-hdfs-namenode 启动失败"
  else
    echo "本机 hadoop-hdfs-namenode 启动成功"
  fi

  service hadoop-0.20-mapreduce-jobtracker start 1>/dev/null 2>&1
  ret2=${?}
  if [ ${ret2} -ne 0 ];then
    eecho "本机 hadoop-0.20-mapreduce-jobtracker 启动失败"
  else
    echo "本机 hadoop-0.20-mapreduce-jobtracker 启动成功"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}

start_hadoop_remote()
{
  ssh "${1}" "service hadoop-hdfs-datanode start" 1>/dev/null 2>&1
  ret1=${?}
  if [ ${ret1} -ne 0 ];then
    eecho "${1} hadoop-hdfs-datanode 启动失败"
  else
    echo "${1} hadoop-hdfs-datanode 启动成功"
  fi

  ssh "${1}" "service hadoop-0.20-mapreduce-tasktracker start" 1>/dev/null 2>&1
  ret2=${?}
  if [ ${ret2} -ne 0 ];then
    eecho "${1} hadoop-0.20-mapreduce-tasktracker 启动失败"
  else
    echo "${1} hadoop-0.20-mapreduce-tasktracker 启动成功"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}



# 只有本机才有hive
start_hive_local()
{
  service hive-metastore start 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    eecho "本机 hive-metastore 启动失败"
  else
    echo "本机 hive-metastore 启动成功"
  fi
  return ${ret}
}


# 本机仅仅 state-store 和 catelog
start_petabase_local()
{
  service petabase-state-store start 1>/dev/null 2>&1
  ret1=${?}
  if [ ${ret1} -ne 0 ];then
    eecho "本机 petabase-state-store 启动失败"
  else
    echo "本机 petabase-state-store 启动成功"
  fi

  service petabase-catalog start 1>/dev/null 2>&1
  ret2=${?}
  if [ ${ret2} -ne 0 ];then
    eecho "本机 petabase-catalog 启动失败"
  else
    echo "本机 petabase-catalog 启动成功"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}

# 远程机器仅仅 server
start_petabase_remote()
{  
  ssh "${1}" "service petabase-server start"  1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    eecho  "${1} petabase-server 启动失败"
  else
    echo  "${1} petabase-server 启动成功"
  fi
  return ${ret}
}

# 通过传入参数指定host来获知
start_secondary_namenode()
{
  ssh "${1}" "service hadoop-hdfs-secondarynamenode start" 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    eecho "${1} hadoop-hdfs-secondarynamenode 启动失败"
  else
    echo "${1} hadoop-hdfs-secondarynamenode 启动成功"
  fi
  return ${ret}
}

start_zookeeper()
{
  start_zookeeper_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    start_zookeeper_remote "${host}"
    ret=${?}||${ret}
  done
  return ${ret}
}

start_hadoop()
{
  start_hadoop_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    start_hadoop_remote ${host}
    ret=${?}||${ret}
  done
  start_secondary_namenode ${SECONDARY_NAMENODE}

  return ${ret}

}


start_hive()
{
  start_hive_local
  ret=$?
  return ${ret}
}


start_petabase()
{
  start_petabase_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    start_petabase_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}
}




# 如果服务正常运行，service xxx status 会返回0
# 如果服务停止，service xxx status 一般会返回3，zookeeper是1
# 总之，非正常运行返回非0
status_zookeeper_local()
{
  service zookeeper-server status 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    wecho "本机 zookeeper-server 未启动"
  else
    echo "本机 zookeeper-server 已启动"
  fi
  return ${ret}
}

status_zookeeper_remote()
{
  ssh "${1}" "service zookeeper-server status"  1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    wecho  "${1} zookeeper-server 未启动"
  else
    echo  "${1} zookeeper-server 已启动"
  fi
  return ${ret}
}


# 该函数用于，查看状态。启动服务时候的报告
status_zookeeper()
{
  status_zookeeper_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    status_zookeeper_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}
}

# local 一般就是 namenode， 我们默认在本机上部署namenode，且在本机上面执行所有的脚本
status_hadoop_local()
{
  service hadoop-hdfs-namenode status 1>/dev/null 2>&1
  ret1=$?
  if [ ${ret1} -ne 0 ];then
    wecho "本机 hadoop-hdfs-namenode 未启动"
  else
    echo "本机 hadoop-hdfs-namenode 已启动"
  fi

  service hadoop-0.20-mapreduce-jobtracker status 1>/dev/null 2>&1
  ret2=$?
  if [ ${ret2} -ne 0 ];then
    wecho "本机 hadoop-0.20-mapreduce-jobtracker 未启动"
  else
    echo "本机 hadoop-0.20-mapreduce-jobtracker 已启动"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}

status_hadoop_remote()
{
  ssh "${1}" "service hadoop-hdfs-datanode status" 1>/dev/null 2>&1
  ret1=$?
  if [ ${ret1} -ne 0 ];then
    wecho "${1} hadoop-hdfs-datanode 未启动"
  else
    echo "${1} hadoop-hdfs-datanode 已启动"
  fi

  ssh "${1}" "service hadoop-0.20-mapreduce-tasktracker status" 1>/dev/null 2>&1
  ret2=${?}
  if [ ${ret2} -ne 0 ];then
    wecho "${1} hadoop-0.20-mapreduce-tasktracker 未启动"
  else
    echo "${1} hadoop-0.20-mapreduce-tasktracker 已启动"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}

status_hadoop()
{
  status_hadoop_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    status_hadoop_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}

}


# 只有本机才有hive的状态
status_hive_local()
{
  service hive-metastore status 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    wecho "本机 hive-metastore 未启动"
  else
    echo "本机 hive-metastore 已启动"
  fi
  return ${ret}
}

status_hive()
{
  status_hive_local
  ret=$?
  return ${ret}
}

# 本机仅仅 state-store 和 catelog
status_petabase_local()
{
  service petabase-state-store status 1>/dev/null 2>&1
  ret1=$?
  if [ ${ret1} -ne 0 ];then
    wecho "本机 petabase-state-store 未启动"
  else
    echo "本机 petabase-state-store 已启动"
  fi

  service petabase-catalog status 1>/dev/null 2>&1
  ret2=${?}
  if [ ${ret2} -ne 0 ];then
    wecho "本机 petabase-catalog 未启动"
  else
    echo "本机 petabase-catalog 已启动"
  fi
  ret=${ret1}||${ret2}

  return ${ret}
}

# 远程机器仅仅 server
status_petabase_remote()
{  
  ssh "${1}" "service petabase-server status"  1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    wecho  "${1} petabase-server 未启动"
  else
    echo  "${1} petabase-server 已启动"
  fi
  return ${ret}
}

status_petabase()
{
  status_petabase_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    status_petabase_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}
}


status_secondary_namenode()
{
  ssh "${1}" "service hadoop-hdfs-secondarynamenode status" 1>/dev/null 2>&1
  ret=$?
  if [ ${ret} -ne 0 ];then
    wecho "${1} hadoop-hdfs-secondarynamenode 未启动"
  else
    echo "${1} hadoop-hdfs-secondarynamenode 已启动"
  fi
  return ${ret}
}


stop_zookeeper_local()
{
  echo "本机即将停止服务  zookeeper-server"
  service zookeeper-server stop 1>/dev/null 2>&1
}

stop_zookeeper_remote()
{
  echo "${1} 即将停止服务  zookeeper-server"
  ssh "${1}" "service zookeeper-server stop"  1>/dev/null 2>&1
}


# 未判断参数，直接就停止了本机 不会用到
stop_zookeeper()
{
  stop_zookeeper_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    stop_zookeeper_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}
}

stop_hadoop_local()
{
  echo "本机即将停止服务  hadoop-hdfs-namenode"
  service hadoop-hdfs-namenode stop 1>/dev/null 2>&1

  echo "本机即将停止服务  hadoop-0.20-mapreduce-jobtracker"
  service hadoop-0.20-mapreduce-jobtracker stop 1>/dev/null 2>&1
}

stop_hadoop_remote()
{
  echo "${1} 即将停止服务  hadoop-hdfs-datanode"
  ssh "${1}" "service hadoop-hdfs-datanode stop" 1>/dev/null 2>&1

  echo "${1} 即将停止服务  hadoop-0.20-mapreduce-tasktracker"
  ssh "${1}" "service hadoop-0.20-mapreduce-tasktracker stop" 1>/dev/null 2>&1

  return ${ret}
}


stop_hadoop()
{
  stop_hadoop_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    stop_hadoop_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}

}

# 只有本机才有hive
stop_hive_local()
{
  echo "本机即将停止服务  hive-metastore"
  service hive-metastore stop 1>/dev/null 2>&1
}

stop_hive()
{
  stop_hive_local
  ret=$?
  return ${ret}
}

# 本机仅仅 state-store 和 catelog
stop_petabase_local()
{
  echo "本机即将停止服务  petabase-state-store"
  service petabase-state-store stop 1>/dev/null 2>&1

  echo "本机即将停止服务  petabase-catalog"
  service petabase-catalog stop 1>/dev/null 2>&1

  return ${ret}
}

# 远程机器仅仅 server
stop_petabase_remote()
{  
  echo "${1}即将停止服务  petabase-server"
  ssh "${1}" "service petabase-server stop"  1>/dev/null 2>&1
}

stop_petabase()
{
  stop_petabase_local
  ret=$?
  for host in ${DATANODES[@]};
  do
    stop_petabase_remote ${host}
    ret=${?}||${ret}
  done
  return ${ret}
}

stop_secondary_namenode()
{
  echo "${1} 即将停止服务  hadoop-hdfs-secondarynamenode"
  ssh "${1}" "service hadoop-hdfs-secondarynamenode stop" 1>/dev/null 2>&1
}



# 简单定义一个ssh，只需修改esen_ssh_arg，便可以在所有的ssh命令中使用该参数
# 自定义的依然可以简单的使用ssh
esen-ssh()
{
 esen_ssh_arg=""
 ssh $esen_ssh_arg "$@"
}


construct_soft_dict
construct_host_info
