#!/bin/bash 

real_usr="`whoami`"

type=""

check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 1
fi

usage(){
  cat <<EOF
  usage $0:[-t|-?] [optional args]
  
  -t   control type, init,start,stop,restart,status
  -?   help message

  e.g. $0 -t start
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

init_zookeeper()
{
  echo "[Log] zookeeper initialization"
  chown -R zookeeper /var/lib/zookeeper/
  sudo service zookeeper-server init --myid=1
}

start_zookeeper()
{
  sleep 3
  echo "[Log] start zookeeper"
  sudo service zookeeper-server start
}

stop_zookeeper()
{
  sleep 3
  echo "[Log] stop zookeeper"
  sudo service zookeeper-server stop
}

init_hadoop()
{
  echo "[Log] hadoop initialization"
  echo "the hadoop data folder will be removed!"
  sudo rm -rf /data
  sudo mkdir -p /data/1/dfs/nn
  sudo mkdir -p /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn
  sudo chown -R hdfs:hdfs /data/1/dfs/nn /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn
  sudo chmod 700 /data/1/dfs/nn
  sudo -u hdfs hdfs namenode -format
  for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x start ; done
  sudo -u hdfs hadoop fs -mkdir /tmp
  sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
  sudo mkdir -p /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local
  sudo chown -R mapred:hadoop /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local
  sudo -u hdfs hadoop fs -mkdir -p /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
  sudo -u hdfs hadoop fs -chmod 1777 /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
  sudo -u hdfs hadoop fs -chown -R mapred /var/lib/hadoop-hdfs/cache/mapred
  sudo -u hdfs hadoop fs -mkdir -p /tmp/mapred/system
  sudo -u hdfs hadoop fs -chown mapred:hadoop /tmp/mapred/system
  sudo service hadoop-0.20-mapreduce-tasktracker start
  sudo service hadoop-0.20-mapreduce-jobtracker start
}

init_hive()
{
  echo "[Log] hive initialization"
  sudo -u hdfs hadoop fs -mkdir -p /user/hive/warehouse
  sudo -u hdfs hdfs dfs -chmod 777 /user
  sudo -u hdfs hdfs dfs -chmod 1777 /user/hive
  sudo -u hdfs hdfs dfs -chmod 1777 /user/hive/warehouse
}

start_hadoop()
{
  sleep 3
  echo "[Log] start hadoop"
  for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x start ; done
  sudo service hadoop-0.20-mapreduce-tasktracker start
  sudo service hadoop-0.20-mapreduce-jobtracker start
}

stop_hadoop()
{
  sleep 3
  echo "[Log] stop hadoop"
  sudo service hadoop-0.20-mapreduce-tasktracker stop
  sudo service hadoop-0.20-mapreduce-jobtracker stop
  for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x stop ; done
}

start_hive()
{
  sleep 3
  echo "[Log] start hive"
  sudo service hive-metastore start
  sudo service hive-server2 start
}

stop_hive()
{
  sleep 3
  echo "[Log] stop hive"
  sudo service hive-server2 stop
  sudo service hive-metastore stop
}

start_petabase()
{
  sleep 3
  echo "[Log] start PetaBase"
  sudo service petabase-state-store start
  sleep 3
  sudo service petabase-catalog start
  sleep 3
  sudo service petabase-server start
}

stop_petabase()
{
  sleep 3
  echo "[Log] stop PetaBase"
  sudo service petabase-server stop
  sudo service petabase-state-store stop
  sudo service petabase-catalog stop
}

status_usual()
{
  echo "[Log] status "
  sudo service zookeeper-server status
  for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x status ; done
  sudo service hadoop-0.20-mapreduce-tasktracker status
  sudo service hadoop-0.20-mapreduce-jobtracker status
  sudo service hive-metastore status
  sudo service hive-server2 status
  sudo service petabase-state-store status
  sudo service petabase-catalog status
  sudo service petabase-server status
}

start_first_time()
{
  init_zookeeper
  start_zookeeper
  init_hadoop
  init_hive
  start_hive
  start_petabase
}

start_usual()
{
  start_zookeeper
  start_hadoop
  start_hive
  start_petabase
}

stop_usual()
{
  stop_petabase
  stop_hive
  stop_hadoop
  stop_zookeeper
}

######################################################################################

if [ -n "$type" ]; then
  if [ "$type"x = "init"x ]; then
    start_first_time
  elif [ "$type"x = "start"x ]; then
    start_usual
  elif [ "$type"x = "stop"x ]; then
    stop_usual
  elif [ "$type"x = "restart"x ]; then
    stop_usual
    start_usual
  elif [ "$type"x = "status"x ]; then
    status_usual
  else
    echo "invalid type arguments"
  fi
else
  echo "please enter arguments completely"
fi