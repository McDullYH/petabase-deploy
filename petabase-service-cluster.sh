#!/bin/bash 
#
# Description: PetaBase cluster service control

MASTER_HOST="`hostname`"
real_usr="`whoami`"

type=""
hostlist=()
secondnode=""

check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 1
fi

usage(){
  cat <<EOF
  usage $0:[-t|-n|-s|-?] [optional args]
  
  -t   control type, init,start,stop,restart,status
  -n   petabase slaves hostname list
  -s   secondarynamenode hostname
  -?   help message

  e.g. $0 -t start -n bigdata2,bigdata3,bigdata4,bigdata5 -s bigdata2
  e.g. $0 -t start -n esen-petabase-234,esen-petabase-235 -s esen-petabase-234
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

init_zookeeper()
{
  echo "[Log] zookeeper initialization"
  # master node
  echo "now in $MASTER_HOST"
  chown -R zookeeper /var/lib/zookeeper/  
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh ${SSH_ARGS[@]} $node "chown -R zookeeper /var/lib/zookeeper/" 1>/dev/null 2>&1
    fi
  done  
  # read zoo.cfg to init zookeeper
  cat /etc/zookeeper/conf/zoo.cfg | grep server | grep -P '^(?!#)' |while read line
  do
    number=`echo $line | awk -F ":" '{print $1}' | awk -F [.] '{print $2}' | awk -F [=] '{print $1}'`
    nodename=`echo $line | awk -F ":" '{print $1}' | awk -F [.] '{print $2}' | awk -F [=] '{print $2}'`
    echo $nodename myid is $number
    ssh -tt -t $nodename "sudo service zookeeper-server init --myid=$number"
  done
}

start_zookeeper()
{
  echo "[Log] start zookeeper"
  # master node
  echo "now in $MASTER_HOST"
  sudo service zookeeper-server start
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service zookeeper-server start"
    fi
  done
}

stop_zookeeper()
{
  echo "[Log] stop zookeeper"
  # master node
  echo "now in $MASTER_HOST"
  sudo service zookeeper-server stop
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service zookeeper-server stop"
    fi
  done
}

init_hadoop()
{
  echo "[Log] hadoop initialization"
  echo "the hadoop data folder will be removed!"

  # master node
  echo "now in $MASTER_HOST"
  rm -rf /data
  mkdir -p /data/1/dfs/nn
  chmod 700 /data/1/dfs/nn
  chown -R hdfs:hdfs /data/1/dfs/nn
  mkdir -p /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local
  chown -R mapred:hadoop /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh ${SSH_ARGS[@]} $node "rm -rf /data"
      ssh ${SSH_ARGS[@]} $node "mkdir -p /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn"
      ssh ${SSH_ARGS[@]} $node "chown -R hdfs:hdfs /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn"
      ssh ${SSH_ARGS[@]} $node "mkdir -p /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local"
      ssh ${SSH_ARGS[@]} $node "chown -R mapred:hadoop /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local"
    fi
  done

  # master node
  echo "now in $MASTER_HOST"
  sudo -u hdfs hdfs namenode -format

  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-hdfs-namenode start

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service hadoop-hdfs-datanode start"
    fi
  done

  # master node
  echo "now in $MASTER_HOST"
  sudo -u hdfs hadoop fs -mkdir /tmp
  sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
  sudo -u hdfs hadoop fs -mkdir -p /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
  sudo -u hdfs hadoop fs -chmod 1777 /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
  sudo -u hdfs hadoop fs -chown -R mapred /var/lib/hadoop-hdfs/cache/mapred
  sudo -u hdfs hadoop fs -mkdir -p /tmp/mapred/system
  sudo -u hdfs hadoop fs -chown mapred:hadoop /tmp/mapred/system

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service hadoop-0.20-mapreduce-tasktracker start"
    fi
  done

  #hadoop-secondarynamenode
  ssh -tt -t $secondnode "sudo service hadoop-hdfs-secondarynamenode start"

  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-0.20-mapreduce-jobtracker start
}

start_hadoop()
{
  echo "[Log] start hadoop"
  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-hdfs-namenode start

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service hadoop-hdfs-datanode start"
    fi
  done

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service hadoop-0.20-mapreduce-tasktracker start"
    fi
  done

  #hadoop-secondarynamenode
  echo "now in $secondnode"
  ssh -tt -t $secondnode "sudo service hadoop-hdfs-secondarynamenode start"

  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-0.20-mapreduce-jobtracker start
}

stop_hadoop()
{
  echo "[Log] stop hadoop"
  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-hdfs-namenode stop
  sudo service hadoop-0.20-mapreduce-jobtracker stop

  #hadoop-secondarynamenode
  echo "now in $secondnode"
  ssh -tt -t $secondnode "sudo service hadoop-hdfs-secondarynamenode stop"

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service hadoop-hdfs-datanode stop"
      ssh -tt -t $node "sudo service hadoop-0.20-mapreduce-tasktracker stop"
    fi
  done
}

start_hive()
{
  echo "[Log] start hive"
  echo "now in $MASTER_HOST"
  sudo service hive-metastore start
  sudo service hive-server2 start
}

stop_hive()
{
  echo "[Log] stop hive"
  echo "now in $MASTER_HOST"
  sudo service hive-server2 stop
  sudo service hive-metastore stop
}

init_hive()
{
  echo "[Log] hive initialization"
  sudo -u hdfs hadoop fs -mkdir -p /user/hive/warehouse
  sudo -u hdfs hdfs dfs -chmod 777 /user
  sudo -u hdfs hdfs dfs -chmod 1777 /user/hive
  sudo -u hdfs hdfs dfs -chmod 1777 /user/hive/warehouse
}

start_petabase()
{
  echo "[Log] start PetaBase"
  #PetaBase masters
  echo "now in $MASTER_HOST"
  sudo service petabase-state-store start
  sleep 3
  sudo service petabase-catalog start
  #sleep 3
  #sudo service petabase-server start

  #PetaBase slaves
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      sleep 3
      ssh -tt -t $node "sudo service petabase-server start"
    fi
  done
}

stop_petabase()
{
  echo "[Log] stop PetaBase"
  #PetaBase masters
  #echo "now in $MASTER_HOST"
  #sudo service petabase-server stop

  #PetaBase slaves
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service petabase-server stop"
    fi
  done

  echo "now in $MASTER_HOST"
  sudo service petabase-state-store stop
  sudo service petabase-catalog stop
  sleep 3
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

status_usual()
{
  echo "[Log] status "
  # master node
  echo "now in $MASTER_HOST"
  sudo service zookeeper-server status
  sudo service hadoop-hdfs-namenode status
  sudo service hadoop-0.20-mapreduce-jobtracker status
  sudo service hive-metastore status
  sudo service hive-server2 status
  sudo service petabase-state-store status
  sudo service petabase-catalog status
  #sudo service petabase-server status

  #hadoop-secondarynamenode
  echo "now in $secondnode"
  ssh -tt -t $secondnode "sudo service hadoop-hdfs-secondarynamenode status"
  
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -tt -t $node "sudo service zookeeper-server status"
      ssh -tt -t $node "sudo service hadoop-hdfs-datanode status"
      ssh -tt -t $node "sudo service hadoop-0.20-mapreduce-tasktracker status"
      ssh -tt -t $node "sudo service petabase-server status"
    fi
  done
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
