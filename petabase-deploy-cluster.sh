#!/bin/bash

SCRIPT_DIR="$(cd "$( dirname "$0")" && pwd)"

if [ -e "./ssh_config" ];then
  SSH_ARGS=(-F ./ssh_config)
fi

real_usr="`whoami`"
check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 1
fi

java_main=/usr/java
java_name=jdk1.7.0_45
java_dir=$java_main/$java_name


PETA_USER="petabase"
PETA_GRP="petabase"
ESEN_DIR=${SCRIPT_DIR}
ESEN_PETA=${ESEN_DIR%/*}
MASTER_HOST="`hostname`"


zoo_version="3.4.5+cdh5.3.0+81-1.cdh5.3.0.p0.36.el6.x86_64"
cdh_version="2.5.0+cdh5.3.0+781-1.cdh5.3.0.p0.54.el6.x86_64"
hive_version="0.13.1+cdh5.3.0+306-1.cdh5.3.0.p0.29.el6.noarch"
hbase_version="hbase-0.98.6+cdh5.3.0+73-1.cdh5.3.0.p0.25.el6.x86_64"
peta_version="2.1.0+cdh5.3.0-el6.x86_64"

type=""
hostlist=()
secondnode=""

usage(){
  cat <<EOF
  usage $0:[-t|-n|-s|-?] [optional args]
  
  -t   install type, install,uninstall,change
  -n   petabase slaves hostname list
  -s   secondarynamenode hostname
  -?   help message
  
  e.g. $0 -t install -n bigdata2,bigdata3 -s bigdata2
  e.g. $0 -t uninstall -n bigdata2,bigdata3 -s bigdata2
EOF
exit 1
}

while getopts "t:n:s:?:" options;do
  case $options in
    t ) type="$OPTARG";;
    n ) IFS=',' hostlist=($OPTARG);;
    s ) secondnode="$OPTARG";;
    \? ) usage;;
    * ) usage;;
  esac
done;

check_user-group()
{
  id ${PETA_USER} 1>/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    # groupadd petabase
    # useradd petabase -g petabase
    groupadd ${PETA_GRP} >/dev/null;
    useradd ${PETA_USER} -g ${PETA_GRP} >/dev/null;
      if [ $? -ne 0 ];then
        echo "Unable to create user or group to $MASTER_HOST"
      fi
  fi
}

check_user-group_slaves()
{
  # echo "check user and group on cluster"
  for host in ${hostlist[@]}; do
  ssh ${SSH_ARGS[@]} $host "id ${PETA_USER}" 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      ssh ${SSH_ARGS[@]} $host "groupadd ${PETA_GRP}" 1>/dev/null 2>&1
      ssh ${SSH_ARGS[@]} $host "useradd ${PETA_USER} -g ${PETA_GRP}" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to create user or group to $host"
      fi
    fi
  done
}

copy_esen_software()
{
for host in ${hostlist[@]}; do
  echo "Copying $ESEN_PETA/software/ for:  $host"
  ssh ${SSH_ARGS[@]} $host "mkdir -p $ESEN_PETA/" 1>/dev/null 2>&1
  rsync -avzu --progress $ESEN_PETA/software $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to copy $ESEN_PETA/software/ to $host:$ESEN_PETA/software/"
    fi
done
}

install_jdk()
{
  mkdir -p /usr/java
  tar xzvf $ESEN_PETA/software/jdk-7u45-linux-x64.tar.gz -C /usr/java/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install jdk  $MASTER_HOST"
      return 0
    fi
  cat $ESEN_PETA/software/java_env  >> /etc/profile
  source /etc/profile
  return 1
}

install_zookeeper()
{
  # bigtop-utils
  rpm -ivh $ESEN_PETA/software/bigtop-utils-0.7.0+cdh5.3.0+0-1.cdh5.3.0.p0.35.el6.noarch.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install bigtop-utils to $MASTER_HOST"
    fi

  # zookeeper
  rpm -ivh $ESEN_PETA/software/zookeeper-$zoo_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install zookeeper to $MASTER_HOST"
    fi

  # zookeeper-server
  rpm -ivh $ESEN_PETA/software/zookeeper-server-$zoo_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install zookeeper-server to $MASTER_HOST"
    fi
}

install_cdh_namenode()
{
  # parquet
  rpm -ivh --nodeps $ESEN_PETA/software/parquet-1.5.0+cdh5.3.0+52-1.cdh5.3.0.p0.27.el6.noarch.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install parquet to $MASTER_HOST"
    fi

  # parquet-format
  rpm -ivh --nodeps $ESEN_PETA/software/parquet-format-2.1.0+cdh5.3.0+6-1.cdh5.3.0.p0.36.el6.noarch.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install parquet-format to $MASTER_HOST"
    fi

  # avro-libs
  rpm -ivh $ESEN_PETA/software/avro-libs-1.7.6+cdh5.3.0+73-1.cdh5.3.0.p0.36.el6.noarch.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install avro-libs to $MASTER_HOST"
    fi

  # nc
  yum install -y nc 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install nc to $MASTER_HOST"
    fi

  # hadoop
  rpm -ivh $ESEN_PETA/software/hadoop-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop to $MASTER_HOST"
    fi

  # bigtop-jsvc
  rpm -ivh $ESEN_PETA/software/bigtop-jsvc-0.6.0+cdh5.3.0+613-1.cdh5.3.0.p0.30.el6.x86_64.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install bigtop-jsvc to $MASTER_HOST"
    fi

  # hadoop-hdfs
  rpm -ivh $ESEN_PETA/software/hadoop-hdfs-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs to $MASTER_HOST"
    fi

  # hadoop-0.20-mapreduce
  rpm -ivh $ESEN_PETA/software/hadoop-0.20-mapreduce-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-0.20-mapreduce to $MASTER_HOST"
    fi

  # hadoop-0.20-mapreduce-jobtracker
  rpm -ivh $ESEN_PETA/software/hadoop-0.20-mapreduce-jobtracker-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-0.20-mapreduce-jobtracker to $MASTER_HOST"
    fi

  # hadoop-hdfs-namenode
  rpm -ivh $ESEN_PETA/software/hadoop-hdfs-namenode-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs-namenode to $MASTER_HOST"
    fi

  # hadoop-libhdfs
  rpm -ivh $ESEN_PETA/software/hadoop-libhdfs-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-libhdfs to $MASTER_HOST"
    fi

  # hadoop-yarn
  rpm -ivh $ESEN_PETA/software/hadoop-yarn-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-yarn to $MASTER_HOST"
    fi

  # hadoop-mapreduce
  rpm -ivh $ESEN_PETA/software/hadoop-mapreduce-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-mapreduce to $MASTER_HOST"
    fi

  # hadoop-client
  rpm -ivh $ESEN_PETA/software/hadoop-client-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-client to $MASTER_HOST"
    fi

}

install_hive()
{
  # sentry
  rpm -ivh $ESEN_PETA/software/sentry-1.4.0+cdh5.3.0+126-1.cdh5.3.0.p0.26.el6.noarch.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install sentry to $MASTER_HOST"
    fi

  # hive-jdbc
  rpm -ivh $ESEN_PETA/software/hive-jdbc-$hive_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hive-jdbc to $MASTER_HOST"
    fi

  # hive
  rpm -ivh $ESEN_PETA/software/hive-$hive_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hive to $MASTER_HOST"
    fi

  # hive-metastore
  rpm -ivh $ESEN_PETA/software/hive-metastore-$hive_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hive-metastore to $MASTER_HOST"
    fi

  # hive-server2
  rpm -ivh $ESEN_PETA/software/hive-server2-$hive_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hive-server2 to $MASTER_HOST"
    fi
}

install_hbase()
{
  # hbase
  rpm -ivh $ESEN_PETA/software/$hbase_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hbase to $MASTER_HOST"
    fi
}

install_petabase()
{
  yum install -y python-setuptools 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install python-setuptools to $MASTER_HOST"
    fi

  # petabase
  rpm -ivh  --nodeps $ESEN_PETA/software/petabase-$peta_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install petabase to $MASTER_HOST"
    fi
}

install_petabase-shell()
{
  # petabase-shell
  rpm -ivh $ESEN_PETA/software/petabase-shell-$peta_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install petabase-shell to $MASTER_HOST"
    fi
}

install_soft_namenode()
{
  echo "[Log] install jdk on $MASTER_HOST"
  install_jdk
  echo "[Log] install zookeeper on $MASTER_HOST"
  install_zookeeper
  echo "[Log] install hadoop on $MASTER_HOST"
  install_cdh_namenode
  echo "[Log] install hive on $MASTER_HOST"
  install_hive
  echo "[Log] install hbase on $MASTER_HOST"
  install_hbase
  echo "[Log] install petabase on $MASTER_HOST"
  install_petabase
  echo "[Log] install petabase-shell on $MASTER_HOST"
  install_petabase-shell
}

uninstall_namenode()
{

  rm -rf /usr/java
  sed -i '/export JAVA_HOME=/'d /etc/profile
  sed -i '/export JRE_HOME=/'d /etc/profile
  sed -i '/export CLASSPATH=/'d /etc/profile
  sed -i '/export PATH=/'d /etc/profile


  rpm -e --nodeps bigtop-utils-0.7.0+cdh5.3.0+0-1.cdh5.3.0.p0.35.el6.noarch 1>/dev/null 2>&1
  rpm -e --nodeps zookeeper-$zoo_version 1>/dev/null 2>&1
  rpm -e --nodeps zookeeper-server-$zoo_version 1>/dev/null 2>&1
  rpm -e --nodeps parquet-1.5.0+cdh5.3.0+52-1.cdh5.3.0.p0.27.el6.noarch 1>/dev/null 2>&1
  rpm -e --nodeps parquet-format-2.1.0+cdh5.3.0+6-1.cdh5.3.0.p0.36.el6.noarch 1>/dev/null 2>&1
  rpm -e --nodeps avro-libs-1.7.6+cdh5.3.0+73-1.cdh5.3.0.p0.36.el6.noarch 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps bigtop-jsvc-0.6.0+cdh5.3.0+613-1.cdh5.3.0.p0.30.el6.x86_64 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-hdfs-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-0.20-mapreduce-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-0.20-mapreduce-jobtracker-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-hdfs-namenode-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-libhdfs-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-yarn-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-mapreduce-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-client-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps sentry-1.4.0+cdh5.3.0+126-1.cdh5.3.0.p0.26.el6.noarch 1>/dev/null 2>&1
  rpm -e --nodeps hive-jdbc-$hive_version 1>/dev/null 2>&1
  rpm -e --nodeps hive-$hive_version 1>/dev/null 2>&1
  rpm -e --nodeps hive-metastore-$hive_version 1>/dev/null 2>&1
  rpm -e --nodeps hive-server2-$hive_version 1>/dev/null 2>&1
  rpm -e --nodeps $hbase_version 1>/dev/null 2>&1
  rpm -e --nodeps petabase-$peta_version 1>/dev/null 2>&1
  rpm -e --nodeps petabase-shell-$peta_version 1>/dev/null 2>&1
  rpm -e --nodeps python-setuptools 1>/dev/null 2>&1
  rpm -e --nodeps nc 1>/dev/null 2>&1
}

uninstall_datanodes()
{
  for hostname in ${hostlist[@]}; do
    echo "clean $hostname"
    ssh ${SSH_ARGS[@]} $hostname "rm -rf /usr/java" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "sed -i '/export JAVA_HOME=/'d /etc/profile" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "sed -i '/export JRE_HOME=/'d /etc/profile" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "sed -i '/export CLASSPATH=/'d /etc/profile" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "sed -i '/export PATH=/'d /etc/profile" 1>/dev/null 2>&1

    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps bigtop-utils-0.7.0+cdh5.3.0+0-1.cdh5.3.0.p0.35.el6.noarch" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps zookeeper-$zoo_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps zookeeper-server-$zoo_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps parquet-1.5.0+cdh5.3.0+52-1.cdh5.3.0.p0.27.el6.noarch" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps parquet-format-2.1.0+cdh5.3.0+6-1.cdh5.3.0.p0.36.el6.noarch" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps avro-libs-1.7.6+cdh5.3.0+73-1.cdh5.3.0.p0.36.el6.noarch" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps bigtop-jsvc-0.6.0+cdh5.3.0+613-1.cdh5.3.0.p0.30.el6.x86_64" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-hdfs-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-0.20-mapreduce-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-0.20-mapreduce-tasktracker-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-hdfs-datanode-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-libhdfs-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-yarn-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-mapreduce-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hadoop-client-$cdh_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps sentry-1.4.0+cdh5.3.0+126-1.cdh5.3.0.p0.26.el6.noarch" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hive-jdbc-$hive_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps hive-$hive_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps $hbase_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps petabase-$peta_version" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps python-setuptools" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps petabase-shell" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $hostname "rpm -e --nodeps nc" 1>/dev/null 2>&1
  done

  uninstall_cdh_secondarynamenode
}

install_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    echo "[Log] install begin on $host"

    echo "[Log] install jdk on $host"

    ssh ${SSH_ARGS[@]} $host "mkdir -p /usr/java" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "tar xzvf $ESEN_PETA/software/jdk-7u45-linux-x64.tar.gz -C /usr/java/" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install jdk to $host"
      fi

  ssh ${SSH_ARGS[@]} $host  "\
  cat $ESEN_PETA/software/java_env >> /etc/profile;\
  source /etc/profile"\
  1>/dev/null 2>&1

    echo "[Log] install zookeeper on $host"
    # bigtop-utils
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/bigtop-utils-0.7.0+cdh5.3.0+0-1.cdh5.3.0.p0.35.el6.noarch.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install bigtop-utils to $host"
      fi
    # zookeeper
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/zookeeper-$zoo_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install zookeeper to $host"
      fi
    # zookeeper-server
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/zookeeper-server-$zoo_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install zookeeper-server to $host"
      fi
    
    echo "[Log] install hadoop on $host"
    # parquet
    ssh ${SSH_ARGS[@]} $host "rpm -ivh --nodeps $ESEN_PETA/software/parquet-1.5.0+cdh5.3.0+52-1.cdh5.3.0.p0.27.el6.noarch.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install parquet to $host"
      fi
    # parquet-format
    ssh ${SSH_ARGS[@]} $host "rpm -ivh --nodeps $ESEN_PETA/software/parquet-format-2.1.0+cdh5.3.0+6-1.cdh5.3.0.p0.36.el6.noarch.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install parquet-format to $host"
      fi
    # avro-libs
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/avro-libs-1.7.6+cdh5.3.0+73-1.cdh5.3.0.p0.36.el6.noarch.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install avro-libs to $host"
      fi
    # nc
    ssh ${SSH_ARGS[@]} $host "yum install -y nc" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install nc to $host"
      fi
    # hadoop
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop to $host"
      fi
    # bigtop-jsvc
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/bigtop-jsvc-0.6.0+cdh5.3.0+613-1.cdh5.3.0.p0.30.el6.x86_64.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install bigtop-jsvc to $host"
      fi
    # hadoop-hdfs
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-hdfs-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-hdfs to $host"
      fi
    # hadoop-0.20-mapreduce
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-0.20-mapreduce-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-0.20-mapreduce to $host"
      fi
    # hadoop-0.20-mapreduce-tasktracker
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-0.20-mapreduce-tasktracker-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-0.20-mapreduce-tasktracker to $host"
      fi
    # hadoop-hdfs-datanode
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-hdfs-datanode-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-hdfs-datanode to $host"
      fi
    # hadoop-libhdfs
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-libhdfs-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-libhdfs to $host"
      fi
    # hadoop-yarn
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-yarn-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-yarn to $host"
      fi
    # hadoop-mapreduce
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-mapreduce-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-mapreduce to $host"
    fi
    # hadoop-client
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hadoop-client-$cdh_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hadoop-client to $host"
      fi

    echo "[Log] install hive on $host"
    # sentry
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/sentry-1.4.0+cdh5.3.0+126-1.cdh5.3.0.p0.26.el6.noarch.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install sentry to $host"
      fi
    # hive-jdbc
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hive-jdbc-$hive_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hive-jdbc to $host"
      fi
    # hive
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/hive-$hive_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hive to $host"
      fi

    echo "[Log] install hbase on $host"
    # hive
    ssh ${SSH_ARGS[@]} $host "rpm -ivh $ESEN_PETA/software/$hbase_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install hbase to $host"
      fi

    echo "[Log] install petabase on $host"
    ssh ${SSH_ARGS[@]} $host "yum install -y python-setuptools" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install python-setuptools to $host"
      fi
    # petabase
    ssh ${SSH_ARGS[@]} $host "rpm -ivh --nodeps $ESEN_PETA/software/petabase-$peta_version.rpm" 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        echo "Unable to install petabase to $host"
      fi

  done

  install_cdh_secondarynamenode
}

install_cdh_secondarynamenode()
{
  # hadoop-hdfs-secondarynamenode
  ssh ${SSH_ARGS[@]} $secondnode "rpm -ivh $ESEN_PETA/software/hadoop-hdfs-secondarynamenode-$cdh_version.rpm" 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs-secondarynamenode to $secondnode"
    fi
}

uninstall_cdh_secondarynamenode()
{
  ssh ${SSH_ARGS[@]} $secondnode "rpm -e --nodeps hadoop-hdfs-secondarynamenode-$cdh_version" 1>/dev/null 2>&1
}

conf_bigtop-utils()
{
  echo "export JAVA_HOME=$java_dir" >> /etc/default/bigtop-utils
  for host in ${hostlist[@]}; do
    scp ${SSH_ARGS[@]} /etc/default/bigtop-utils $host:/etc/default/ 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "chown root:root /etc/default/bigtop-utils" 1>/dev/null 2>&1
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
    ssh ${SSH_ARGS[@]} $host "rm -rf /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "alternatives --display hadoop-conf"
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
    scp ${SSH_ARGS[@]} /etc/zookeeper/conf/zoo.cfg $host:/etc/zookeeper/conf/ 1>/dev/null 2>&1
    # hadoop
    scp ${SSH_ARGS[@]} $ESEN_PETA/configuration/cluster/hadoop/datanodes/core-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} $ESEN_PETA/configuration/cluster/hadoop/datanodes/hdfs-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} $ESEN_PETA/configuration/cluster/hadoop/datanodes/mapred-site.xml $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/hadoop/conf.my_cluster/masters $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/hadoop/conf.my_cluster/slaves $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/default/hadoop $host:/etc/default/ 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "chown root:root /etc/default/hadoop" 1>/dev/null 2>&1
    # hive
    scp ${SSH_ARGS[@]} /etc/hive/conf/hive-site.xml $host:/etc/hive/conf/ 1>/dev/null 2>&1
    # petabase
    scp ${SSH_ARGS[@]} /etc/default/impala $host:/etc/default/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/impala/conf/core-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/impala/conf/hdfs-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    scp ${SSH_ARGS[@]} /etc/impala/conf/hive-site.xml $host:/etc/impala/conf/ 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "chown -R root:root /etc/impala/conf" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "chown root:root /etc/default/impala" 1>/dev/null 2>&1
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
    ssh ${SSH_ARGS[@]} $host "cp -f $ESEN_PETA/software/mysql-connector-java-*.jar /usr/lib/hive/lib" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "usermod -a -G hadoop petabase" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "usermod -a -G hive petabase" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "usermod -a -G hdfs petabase" 1>/dev/null 2>&1
  done
}

change_conf()
{
  conf_namenode
  conf_datanodes
}

clear_node()
{
  userdel -r $PETA_USER 1>/dev/null 2>&1
  groupdel $PETA_GRP 1>/dev/null 2>&1
}

clear_slaves()
{
  for host in ${hostlist[@]}; do
    ssh ${SSH_ARGS[@]} $host "userdel -r $PETA_USER" 1>/dev/null 2>&1
    ssh ${SSH_ARGS[@]} $host "groupdel $PETA_GRP" 1>/dev/null 2>&1
  done
}

check_bin()
{
  local bin=$1
  which $bin 1>/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "binary $bin is required for this script but not found in PATH=$PATH"
  fi
}

check_bin sed
check_bin ssh
check_bin scp
check_bin awk

######################################################################################

if [ "$type"x = "install"x ]; then
  if [ $hostlist ]; then
    echo "[Log `date +%Y%m%d-%T`] install begin"
    # later use a mark to mark whether it has been uninstalled, not uninstall everytime
    uninstall_namenode
    uninstall_datanodes
    echo "[Log] check user and group"
    check_user-group
    check_user-group_slaves
    echo "[Log] copy software to other nodes"
    copy_esen_software
    echo "[Log] install software"
    install_soft_namenode
    install_soft_datanodes
    echo "[Log] configure software"
    conf_bigtop-utils
    prepare_use_hadoop
    prepare_use_hive
    conf_namenode
    conf_datanodes
    echo "[Log `date +%Y%m%d-%T`] finish"
  else
    echo "[Log] no slaves,finish"
  fi
elif [ "$type"x = "uninstall"x ]; then
  if [ $hostlist ]; then
    echo "[Log `date +%Y%m%d-%T`] uninstall begin"
    uninstall_namenode
    uninstall_datanodes
    clear_node
    clear_slaves
    echo "[Log `date +%Y%m%d-%T`] uninstall finish"
  else
    echo "[Log] no slaves,finish"
  fi
elif [ "$type"x = "change"x ]; then
  if [ $hostlist ]; then
    echo "[Log `date +%Y%m%d-%T`] change configuration begin"
    change_conf
    echo "[Log `date +%Y%m%d-%T`] change configuration finish"
  else
    echo "[Log] no slaves,finish"
  fi
elif [ "$type"x = "test"x ]; then

#  for host in ${hostlist[@]}; do
#    echo "[Log] install begin on $host"
#    echo "[Log] install jdk on $host"
#
#    ssh ${SSH_ARGS[@]} $host "mkdir -p /usr/java" 1>/dev/null 2>&1
#    ssh ${SSH_ARGS[@]} $host "tar xzvf $ESEN_PETA/software/jdk-7u45-linux-x64.tar.gz -C /usr/java/" 1>/dev/null 2>&1
#      if [ $? -ne 0 ];then
#        echo "Unable to install jdk to $host"
#      fi
#
#  ssh ${SSH_ARGS[@]} $host  "\
#  cat $ESEN_PETA/software/java_env >> /etc/profile;\
#  source /etc/profile"\
#  1>/dev/null 2>&1
#  done

  for host in ${hostlist[@]}; do
    echo "[Log] install begin on $host"

    echo "[Log] install jdk on $host"

ssh -T ${SSH_ARGS[@]}   $host  << eeooff
	  mkdir -p /usr/java;
	  tar xzvf $ESEN_PETA/software/jdk-7u45-linux-x64.tar.gz -C /usr/java/ 1>/dev/null 2>&1;
	    if [ $? -ne 0 ];then
	      echo "Unable to install jdk  $MASTER_HOST";
	      exit 0
	    fi
	  cat $ESEN_PETA/software/java_env  >> /etc/profile;
	  source /etc/profile;
	  1>/dev/null 2>&1
eeooff

    done


    echo "[Log `date +%Y%m%d-%T`] test finish"
    echo "[Log] test finish"

else
  echo "[Log] invalid type arguments"
fi
