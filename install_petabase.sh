#!/bin/bash

# TODO 先安装MapReduce V1  后期 进行YARN的安装

# 关于使用-ivh参数是否不好的问题:
# petabase的安装很复杂，依赖很多，推荐的方式是在在线环境下使用yum安装，自动解决依赖。
# 但这里，我们需要尽可能的在离线情况下安装，所以，在安装过程中不免出现缺失依赖的问题，
# 使用--nodeps很可能会出现某个软件安装好了，但是因依赖缺乏无法运行的事情，但这本身不是部署人员的错，
# 所以，脚本编写人员清楚依赖关系，并保证各个软件的运行依赖正确安装即可，故此处使用--nodeps不会有问题，
# 如果出现问题，当属安装脚本的bug或者缺陷，应修复



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
EXT_SOFT_DIR=$ESEN_PETA/ext-software

# import temp variable
source ./deploy_config.sh


# do it when successfully install, forbid to reinstall
mark_install()
{
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


check_user-group()
{
  echo "Check ${PETA_USER} user and ${PETA_GRP} group in $MASTER_HOST"
  id ${PETA_USER} 1>/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    groupadd ${PETA_GRP} >/dev/null;
    useradd ${PETA_USER} -g ${PETA_GRP} >/dev/null;
      if [ $? -ne 0 ];then
        eecho "Unable to create user or group to $MASTER_HOST"
	exit 0
      fi
  fi
}

check_user-group_slaves()
{
  for host in ${hostlist[@]}; do
  echo "Check ${PETA_USER} user and ${PETA_GRP} group in $host"
  ssh  $host "id ${PETA_USER}" 1>/dev/null 2>&1
    if [ $? -ne 0 ];then

      #echo "ssh  $host \"groupadd ${PETA_GRP}\" 1>/dev/null 2>&1"
      ssh  $host "groupadd ${PETA_GRP}" 1>/dev/null 2>&1
      ssh  $host "useradd ${PETA_USER} -g ${PETA_GRP}" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        eecho "Unable to create user or group to $host"
	exit 0
      fi
    fi
  done
}



install_jdk()
{
  echo "installing jdk"
  mkdir -p /usr/java;
  tar xzvf $COMMON_SOFT_DIR/jdk-7u45-linux-x64.tar.gz -C /usr/java/ 1>/dev/null 2>&1;
    if [ $? -ne 0 ];then
      eecho "Unable to install jdk  $MASTER_HOST";
      exit 0
    fi
  cat $COMMON_SOFT_DIR/java_env  >> /etc/profile;
  source /etc/profile;
}



# 关于下面的函数 安装rpm包函数的编写方式问题
# 1直接指定rpm包的文件名进行安装；
# 2遍历某个文件夹，安装该文件夹下面的所有rpm包
# 第一种的优势是，直接通过安装脚本就可以知道安装了哪些包
# 第二种的优势是，当有包更新的时候，我们只需要对目录中的rpm包文件进行替换即可，而第一种方法还需要修改包名(冗长的平台，版本号等等)
# 第二种的重大缺陷是，如果一个rpm包缺失，脚本不能自动发现。解决办法是安装脚本以及包发布之后生成一个md5码给部署人员验证
# 这里，我认为第二种方式比较容易维护，故使用之

install_soft_namenode()
{

  echo "[Log] install begin on $MASTER_HOST"

  install_jdk

  for rpm_file in $NAMENODE_SOFT_DIR/*.rpm
  do
    check_and_install_local $rpm_file 
  done

  for rpm_file in $COMMON_SOFT_DIR/*.rpm
  do
    check_and_install_local $rpm_file 
  done

  for rpm_file in $EXT_SOFT_DIR/*.rpm
  do
    check_and_install_local $rpm_file 
  done
}


install_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    echo "[Log] install begin on $host"

    echo "[Log] install jdk on $host"

    # install jdk
    ssh   $host  "mkdir -p /usr/java"
    ssh   $host  "tar xzvf $COMMON_SOFT_DIR/jdk-7u45-linux-x64.tar.gz -C /usr/java/ 1>/dev/null 2>&1"
    if [ $? -ne 0 ];then
      eecho "Unable to install jdk $MASTER_HOST";
      exit 0
    fi
    ssh   $host  "cat $COMMON_SOFT_DIR/java_env  >> /etc/profile"
    ssh   $host  "source /etc/profile"




  echo "[Log] install soft on $host"
  for rpm_file in $DATANODE_SOFT_DIR/*.rpm
  do
    check_and_install_remote $host $rpm_file 
  done

  for rpm_file in $COMMON_SOFT_DIR/*.rpm
  do
    check_and_install_remote $host $rpm_file 
  done

 done

}


install_secondarynamenode()
{

  for rpm_file in $SEC_NAMENODE_SOFT_DIR/*.rpm
  do
    check_and_install_remote $secondnode $rpm_file 
  done

}


conf_bigtop-utils()
{
  echo "export JAVA_HOME=$java_dir" >> /etc/default/bigtop-utils
  for host in ${hostlist[@]}; do
    scp  /etc/default/bigtop-utils $host:/etc/default/ 1>/dev/null 2>&1
    ssh  $host "chown root:root /etc/default/bigtop-utils" 1>/dev/null 2>&1
  done
}

prepare_use_hadoop()
{
  # namenode
  rm -rf /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster 1>/dev/null 2>&1
  alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50 1>/dev/null 2>&1
  alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster 1>/dev/null 2>&1
  alternatives --display hadoop-conf
  
  # datanodes
  for host in ${hostlist[@]}; do
    ssh  $host "rm -rf /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh  $host "cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh  $host "alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50" 1>/dev/null 2>&1
    ssh  $host "alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster" 1>/dev/null 2>&1
    ssh  $host "alternatives --display hadoop-conf"
  done
}

conf_namenode()
{
  # zookeeper
  cp -f $ESEN_PETA/configuration/cluster/zookeeper/zoo.cfg /etc/zookeeper/conf/zoo.cfg 1>/dev/null 2>&1
  # hadoop
  cp -f $ESEN_PETA/configuration/cluster/hadoop/namenode/core-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/hadoop/namenode/hdfs-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/hadoop/namenode/mapred-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/hadoop/masters /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/hadoop/slaves /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/hadoop/hadoop /etc/default/hadoop 1>/dev/null 2>&1
  # hive
  cp -f $ESEN_PETA/configuration/cluster/hive/hive-site.xml /etc/hive/conf/ 1>/dev/null 2>&1
  # petabase
  sed -i "s/127.0.0.1/$MASTER_HOST/g" /etc/default/impala 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/petabase/core-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/petabase/hdfs-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/cluster/petabase/hive-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
}

conf_datanodes()
{
  for host in ${hostlist[@]}; do
    # zookeeper
    scp  /etc/zookeeper/conf/zoo.cfg $host:/etc/zookeeper/conf/ 1>/dev/null 2>&1
    # hadoop
    scp  $ESEN_PETA/configuration/cluster/hadoop/datanodes/core-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  $ESEN_PETA/configuration/cluster/hadoop/datanodes/hdfs-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  $ESEN_PETA/configuration/cluster/hadoop/datanodes/mapred-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  /etc/hadoop/conf.my_cluster/masters $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  /etc/hadoop/conf.my_cluster/slaves $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  /etc/default/hadoop $host:/etc/default/ 1>/dev/null 2>&1
    ssh  $host "chown root:root /etc/default/hadoop" 1>/dev/null 2>&1
    # hive
    scp  /etc/hive/conf/hive-site.xml $host:/etc/hive/conf/ 1>/dev/null 2>&1
    # petabase
    scp  /etc/default/impala $host:/etc/default/ 1>/dev/null 2>&1
    scp  /etc/impala/conf/core-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    scp  /etc/impala/conf/hdfs-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    scp  /etc/impala/conf/hive-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    ssh  $host "chown -R root:root /etc/impala/conf" 1>/dev/null 2>&1
    ssh  $host "chown root:root /etc/default/impala" 1>/dev/null 2>&1
  done
}

prepare_use_hive()
{
  cp -f $ESEN_PETA/software/mysql-connector-java-*.jar /usr/lib/hive/lib 1>/dev/null 2>&1
  cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib 1>/dev/null 2>&1
  usermod -a -G hadoop petabase 1>/dev/null 2>&1
  usermod -a -G hive petabase 1>/dev/null 2>&1
  usermod -a -G hdfs petabase 1>/dev/null 2>&1
  for host in ${hostlist[@]}; do
    ssh  $host "cp -f $ESEN_PETA/software/mysql-connector-java-*.jar /usr/lib/hive/lib" 1>/dev/null 2>&1
    ssh  $host "cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib" 1>/dev/null 2>&1
    ssh  $host "usermod -a -G hadoop petabase" 1>/dev/null 2>&1
    ssh  $host "usermod -a -G hive petabase" 1>/dev/null 2>&1
    ssh  $host "usermod -a -G hdfs petabase" 1>/dev/null 2>&1
  done
}


#install_haproxy()
#{
#}
#
#conf_haproxy()
#{
#}


######################################################################################

if [ $hostlist ]; then
  iecho "`date +%Y%m%d-%T` install begin"
  iecho "check user and group"
  check_user-group
  check_user-group_slaves
  iecho "install software"
  install_soft_namenode
  install_soft_datanodes
  install_secondarynamenode
  #install_haproxy
  iecho "configure software"
  conf_bigtop-utils
  prepare_use_hadoop
  prepare_use_hive
  conf_namenode
  conf_datanodes
  #conf_haproxy
  iecho "`date +%Y%m%d-%T` finish"
else
  iecho "no slaves,finish"
fi
