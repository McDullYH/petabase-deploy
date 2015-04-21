#!/bin/bash

SCRIPT_DIR="$(cd "$( dirname "$0")" && pwd)"

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

usage(){
  cat <<EOF
  usage $0:[-t|-?] [optional args]
  
  -t   install type, install,uninstall,change
  -?   help message
  
  e.g. $0 -t install
  e.g. $0 -t uninstall
EOF
exit 1
}

while getopts "t:?:" options;do
  case $options in
    t ) type="$OPTARG";;
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

install_cdh()
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

  # hadoop-0.20-mapreduce-tasktracker
  rpm -ivh $ESEN_PETA/software/hadoop-0.20-mapreduce-tasktracker-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-0.20-mapreduce-tasktracker to $MASTER_HOST"
    fi

  # hadoop-hdfs-namenode
  rpm -ivh $ESEN_PETA/software/hadoop-hdfs-namenode-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs-namenode to $MASTER_HOST"
    fi

  # hadoop-hdfs-datanode
  rpm -ivh $ESEN_PETA/software/hadoop-hdfs-datanode-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs-datanode to $MASTER_HOST"
    fi

  # hadoop-hdfs-secondarynamenode
  rpm -ivh $ESEN_PETA/software/hadoop-hdfs-secondarynamenode-$cdh_version.rpm 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Unable to install hadoop-hdfs-secondarynamenode to $MASTER_HOST"
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

conf_bigtop-utils()
{
  echo "export JAVA_HOME=$java_dir" >> /etc/default/bigtop-utils
}

conf_zookeeper()
{
  cp -f $ESEN_PETA/configuration/single/zookeeper/zoo.cfg /etc/zookeeper/conf/zoo.cfg 1>/dev/null 2>&1
}

prepare_use_hadoop()
{
rm -rf /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster 1>/dev/null 2>&1
alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50 1>/dev/null 2>&1
alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster 1>/dev/null 2>&1
alternatives --display hadoop-conf
}

conf_hadoop()
{
  cp -f $ESEN_PETA/configuration/single/hadoop/core-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/hadoop/hdfs-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/hadoop/mapred-site.xml /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/hadoop/masters /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/hadoop/slaves /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/hadoop/hadoop /etc/default/ 1>/dev/null 2>&1
}

prepare_use_hive()
{
  cp -f $ESEN_PETA/software/mysql-connector-java-*.jar /usr/lib/hive/lib 1>/dev/null 2>&1
  cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib 1>/dev/null 2>&1
  usermod -a -G hadoop petabase 1>/dev/null 2>&1
  usermod -a -G hive petabase 1>/dev/null 2>&1
  usermod -a -G hdfs petabase 1>/dev/null 2>&1
}

conf_hive()
{
  cp -f $ESEN_PETA/configuration/single/hive/hive-site.xml /etc/hive/conf/ 1>/dev/null 2>&1
}

conf_petabase()
{
  sed -i "s/127.0.0.1/$MASTER_HOST/g" /etc/default/impala
  cp -f $ESEN_PETA/configuration/single/petabase/core-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/petabase/hdfs-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
  cp -f $ESEN_PETA/configuration/single/petabase/hive-site.xml /etc/impala/conf/ 1>/dev/null 2>&1
}

change_conf()
{
	conf_zookeeper
	conf_hadoop
	conf_hive
	conf_petabase
}

uninstall_node()
{
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
  rpm -e --nodeps hadoop-0.20-mapreduce-tasktracker-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-hdfs-namenode-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-hdfs-datanode-$cdh_version 1>/dev/null 2>&1
  rpm -e --nodeps hadoop-hdfs-secondarynamenode-$cdh_version 1>/dev/null 2>&1
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
}

clear_node()
{
  userdel -r $PETA_USER 1>/dev/null 2>&1
  groupdel $PETA_GRP 1>/dev/null 2>&1
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
check_bin awk

######################################################################################

if [ "$type"x = "install"x ]; then
  echo "[Log `date +%Y%m%d-%T`] install begin"
  uninstall_node
  echo "[Log] check user and group"
  check_user-group
  echo "[Log] install zookeeper"
  install_zookeeper
  echo "[Log] install hadoop"
  install_cdh
  echo "[Log] install hive"
  install_hive
  prepare_use_hive
  echo "[Log] install hbase"
  install_hbase
  echo "[Log] install petabase"
  install_petabase
  echo "[Log] install petabase-shell"
  install_petabase-shell
  echo "[Log] configure zookeeper"
  conf_bigtop-utils
  conf_zookeeper
  echo "[Log] configure hadoop"
  prepare_use_hadoop
  conf_hadoop
  echo "[Log] configure hive"
  prepare_use_hive
  conf_hive
  echo "[Log] configure petabase"
  conf_petabase
  echo "[Log `date +%Y%m%d-%T`] finish"
elif [ "$type"x = "uninstall"x ]; then
  echo "[Log `date +%Y%m%d-%T`] uninstall begin"
  uninstall_node
  clear_node
  echo "[Log `date +%Y%m%d-%T`] uninstall finish"
elif [ "$type"x = "change"x ]; then
  echo "[Log `date +%Y%m%d-%T`] change configuration begin"
  change_conf
  echo "[Log `date +%Y%m%d-%T`] change configuration finish"
else
  echo "[Log] invalid type arguments"
fi
