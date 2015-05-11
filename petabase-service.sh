#!/bin/bash 
#
# Description: PetaBase cluster service control

source ./deploy_config.sh

MASTER_HOST="`hostname`"
real_usr="`whoami`"

type=""
hostlist=()
servicelist=()
second_namenode=""

# 合法的服务名 
#zookeeper
#hadoop
#hive
#petabase
# petabase包括 catalog state-store 和 server
# hadoop包括 hdfs和mapreduce相关


check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 1
fi



show_usage(){
  cat <<EOF

  usage: $0 COMMAND OPTIONS

  COMMAND CAN BE
  init  	To init the special service (Recommand not to specify the -s and -n args, to init all services on all host in first time)
  start  	To start the specify service on specify node
  stop  	To stop the specify service on specify node
  restart  	To restart the specify service on specify node
  status  	To see the status of specify service on specify node

  OPTIONS CAN BE:
  SPECIFY THE DATANODE
  	$0 {-n|--nodes} [datanode list] 
	The datanode list should be separated by ',', seems like host1,host2,host3

  SPECIFY THE SECOND NAMENODE
  	$0 {-s|--secondary-namenode} [second-namenode]
	The secondary namenode should be in the datanode list

  USE FILE TO SPECIFY THE DATANODE AND NAMENODE
  	$0 {-f|--nodes-file} [filepath]

  The file format *MUST* be like following:
  	eg:
  	#file specify the datanodes and the second-namenode
	datanode:
	esen-petabase-234,esen-petabase-235
	second-name-node:
	esen-petabase-234
  DON'T forget the ":" !

  SHOW THIS HELP
  	$0 {-h|--help} 


  e.g. $0 init -n esen-petabase-234,esen-petabase-235 -s esen-petabase-234
  e.g. $0 restart -f your_file --service zookeeper,petabase-server
EOF
exit 1
}


arg_check()
{

  if [ ${operate}x = ""x ];then
    wecho "请指定一个操作类型 init/start/stop/restart/status"
    exit 1
  elif [ ${operate}x != "init"x ] && [ ${operate}x != "start"x ] && [ ${operate}x != "stop"x ] && [ ${operate}x != "restart"x ] && [ ${operate}x != "status"x ];then
    wecho "不支持的操作类型  '${operate}' "
    exit 1
  fi

  if [[ -z ${hostlist} ]];then
    wecho "请指定从机列表"
    return 1
  fi

  if [ -z ${second_namenode} ];then
    wecho "请指定第二主机"
    return 1
  fi

  #second_namenode 必须在nodes中
  in=False
  for host in ${hostlist[@]}; do
    if [ ${host} = ${second_namenode} ];then
      in=True
      return 0
    fi
  done
  if [ ${in}x = "False"x ];then
    wecho "第二主机必须是在从机列表中"
    return 1
  fi

  #TODO 服务名的检查
}

show_operate()
{
  iecho "操作类型:	${operate}"
  iecho "从机列表:	${hostlist}"
  iecho "第二主机:	${second_namenode}"
  iecho "服务列表:	${servicelist}"


  iecho "输入 'YES' 将继续操作"
  read  TOGO
  if [ ${TOGO}x = "YES"x ];then
    return 0;
  else
    iecho "操作取消"
    return 1;
  fi
}




# TODO 关于zookeeper 各个node安装的必要性须进一步核实
init_zookeeper()
{
  echo "[Log] zookeeper initialization"
  # master node
  echo "now in $MASTER_HOST"
  mkdir -p /var/lib/zookeeper
  chown -R zookeeper /var/lib/zookeeper/  
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"

      ssh  "${node}"  "mkdir -p /var/lib/zookeeper"
      ssh  "${node}"  "chown -R zookeeper /var/lib/zookeeper/" 
    fi
  done  

  # TODO is there any thing wrong?
  # read zoo.cfg to init zookeeper
  cat /etc/zookeeper/conf/zoo.cfg | grep server | grep -P '^(?!#)' |while read line
  do
    # 冒号分开，取第一个；点好分开，取第二个；等号分开，取第一个
    number=`echo $line | awk -F ":" '{print $1}' | awk -F [.] '{print $2}' | awk -F [=] '{print $1}'`
    # 道理同上
    nodename=`echo $line | awk -F ":" '{print $1}' | awk -F [.] '{print $2}' | awk -F [=] '{print $2}'`
    echo $nodename myid is $number

    # 这里远程操控本机了
    ssh  -t "${nodename}" "service zookeeper-server init --myid=$number"
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
      ssh -t "${node}" "service zookeeper-server start"
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
      ssh -t "${node}" "service zookeeper-server stop"
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

  # TODO mapreduce V1 特有
  mkdir -p /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local
  chown -R mapred:hadoop /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      # 上面是nn 这里是dn
      echo "now in $node"
      ssh ${SSH_ARGS[@]} $node "rm -rf /data"
      ssh ${SSH_ARGS[@]} $node "mkdir -p /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn"
      ssh ${SSH_ARGS[@]} $node "chown -R hdfs:hdfs /data/1/dfs/dn /data/2/dfs/dn /data/3/dfs/dn"

      ssh ${SSH_ARGS[@]} $node "mkdir -p /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local"
      ssh ${SSH_ARGS[@]} $node "chown -R mapred:hadoop /data/1/mapred/local /data/2/mapred/local /data/3/mapred/local"
    fi
  done

  # master node  format
  echo "now in $MASTER_HOST"
  sudo -u hdfs hdfs namenode -format


  # TODO 这里启动了，所以后面会重复启动，但是这里必须启动，不然没法配置mapreduce
  # master node
  echo "now in $MASTER_HOST"
  sudo service hadoop-hdfs-namenode start

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -t $node "service hadoop-hdfs-datanode start"
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
      echo "now in ${node}"
      ssh -t $node "service hadoop-0.20-mapreduce-tasktracker start"
    fi
  done

  #hadoop-secondarynamenode
  ssh -t $second_namenode "service hadoop-hdfs-secondarynamenode start"

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
      ssh -t $node "service hadoop-hdfs-datanode start"
    fi
  done

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -t $node "service hadoop-0.20-mapreduce-tasktracker start"
    fi
  done

  #hadoop-secondarynamenode
  echo "now in $second_namenode"
  ssh -t $second_namenode "service hadoop-hdfs-secondarynamenode start"

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
  echo "now in $second_namenode"
  ssh -t $second_namenode "service hadoop-hdfs-secondarynamenode stop"

  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -t $node "service hadoop-hdfs-datanode stop"
      ssh -t $node "service hadoop-0.20-mapreduce-tasktracker stop"
    fi
  done
}

# hive-server2 服务不需要
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
      ssh -t $node "service petabase-server start"
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
      ssh -t $node "service petabase-server stop"
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
  echo "now in $second_namenode"
  ssh -t  $second_namenode "service hadoop-hdfs-secondarynamenode status"
  
  # slaves node
  for node in ${hostlist[@]}; do
    if [ "${node}" != "${MASTER_HOST}" ]; then
      echo "now in $node"
      ssh -t  $node "service zookeeper-server status"
      ssh -t  $node "service hadoop-hdfs-datanode status"
      ssh -t  $node "service hadoop-0.20-mapreduce-tasktracker status"
      ssh -t  $node "service petabase-server status"
    fi
  done
}

######################################################################################

TEMP=`getopt -o n:s:f:chz:: -l nodes:,secondary-namenode:,nodes-file:,check,help,z-long \
     -n '错误的输入参数' -- "$@" `

if [ $? != 0 ] ; then echo "您可以输入 $0 --help/-h 来查看帮助" >&2 ; exit 1 ; fi
if [ $# = 0 ] ; then echo "没有命令和参数,您可以输入 $0 --help/-h 来查看帮助" >&2 ; exit 1 ; fi

eval set -- "$TEMP"



while true ; do
  case "$1" in
# c 和 h 选项是没有参数的，如果使用了$2，会直接取下一个参数
     -n|--nodes) 
       IFS=','; hostlist=$2;
       #echo "Option $1's argument is $hostlist"; 
       shift 2 ;;

     -s|--secondary-namenode) 
       second_namenode=$2;
       #echo "Option $1's argument is $second_namenode"; 
       shift 2 ;;

     -f|--nodes-file) 
       FILE=$2;
       #echo "Option $1's argument is $FILE"; 
       if [ ! -r $FILE ];then
         wecho "文件 ${FILE} 不存在或者不可读"
	 exit 1
       fi
       while read LINE
       do
	 if [ ${LINE}x = "second-name-node:"x ];then
	 read LINE
	 second_namenode=$LINE
	 fi
	 if [ ${LINE}x = "datanode:"x ];then
	 read LINE
         IFS=','; hostlist=$LINE;
	 fi
	 done  <${FILE}
       shift 2 ;;


     -d|--service)
       IFS=','; servicelist=$2;
       #echo "Option $1's argument is $servicelist"; 
       shift 2 ;;

     -c|--check) 
       $CHECK=true; 
       #echo "Option $1's argument is $CHECK" ; 
       shift ;;

     -h|--help)  
       HELP=true;  
       #echo "Option $1's argument is $HELP" ; 
       shift ;;

 #z has an optional argument. As we are in quoted mode,
 #an empty parameter will be generated if its optional
 #argument is not found.
       -z|--z-long)
       case "$2" in
       "") echo "Option $1, no argument"; shift 2 ;;
       *)  echo "Option $1's argument is $2" ; shift 2 ;;
       esac ;;
     --) shift ; break ;;
     *) echo "Internal error!" ; exit 1 ;;
  esac
done

#echo "Remaining arguments:"
#for arg do
# echo '--> ' "$arg" ;
#done

if [ "${HELP}"x = "true"x ];then
show_usage
exit 0
fi

operate=${1}

arg_check
if [ $? = 1 ];then
  exit 1
fi

show_operate
if [ $? = 1 ];then
  exit 1;
fi


if [ -n "${operate}" ]; then
  if [ "${operate}"x = "init"x ]; then
    start_first_time
  elif [ "${operate}"x = "start"x ]; then
    start_usual
  elif [ "${operate}"x = "stop"x ]; then
    stop_usual
  elif [ "${operate}"x = "restart"x ]; then
    stop_usual
    start_usual
  elif [ "${operate}"x = "status"x ]; then
    status_usual
  else
    echo "invalid type arguments"
  fi
else
  echo "please enter arguments completely"
fi
