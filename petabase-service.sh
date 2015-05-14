#!/bin/bash 
# # Description: PetaBase cluster service control


# 对于某个host某个服务的控制可能用的不多，要么是全部一起启动，停止，要么就会ssh到具体的host来进行具体的服务操作
source ./deploy_config.sh

MASTER_HOST="`hostname`"
real_usr="`whoami`"

type=""
hostlist=""
servicelist=""
second_namenode=""
include_master="否"

check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 1
fi

show_usage(){
  cat <<EOF

  usage: $0 COMMAND OPTIONS

  COMMAND CAN BE
  start  	To start the specify service on specify node
  stop  	To stop the specify service on specify node
  restart  	To restart the specify service on specify node
  status  	To see the status of specify service on specify node

  OPTIONS CAN BE:

  SPECIFY WHETHER CONTROL THE NAMENODE(THIS HOST)
  	$0 {-m|--master} 

  SPECIFY THE DATANODE
  	$0 {-n|--nodes} [datanode list] 
	The datanode list should be separated by ',', just like host1,host2,host3

  SPECIFY THE SECOND NAMENODE
  	$0 {-s|--secondary-namenode} [second-namenode]
	The secondary namenode should be in the datanode list

  USE FILE TO SPECIFY THE DATANODE AND NAMENODE
  	$0 {-f|--nodes-file} [filepath]

  SPECIFY THE SERVICE
  	$0 {-d|--service} [service list]
	The service include:
	 zookeeper
	 hadoop
	 hive
	 petabase
	The service list should be separated by ',', just like hadoop,petabase,hive


  The file format *MUST* be like following:
  	eg:
  	#file specify the datanodes and the second-namenode
	datanodes:
	esen-petabase-234,esen-petabase-235
	second-name-node:
	esen-petabase-234
        DON'T forget the ":" ! And the last 's' after 'datanodes'

  SHOW THIS HELP
  	$0 {-h|--help} 


  e.g. $0 status -n esen-petabase-234,esen-petabase-235 -s esen-petabase-234 --service hadoop,zookeeper
  e.g. $0 restart -f your_file --service zookeeper,petabase-server


  *IF YOU JUST SPECIFY THE SERVICE LIST ,ALL THE HOST WILL IN CONTROL*
  e.g. $0 start --service hive,petabase


  *IF YOU JUST USE COMMAND AND NOT ANY HOST, THIS SCRIPT WILL CONTROL ALL THE HOST IN THE CLUST, THIS IS THE *RECOMMMANED* WAY*
  e.g. $0 start
  e.g. $0 stop
  e.g. $0 status

EOF
exit 1
}



arg_check()
{
  if [ ${operate}x = ""x ];then
    wecho "请指定一个操作类型 start/stop/restart/status"
    exit 1
  elif [ ${operate}x != "start"x ] && [ ${operate}x != "stop"x ] && [ ${operate}x != "restart"x ] && [ ${operate}x != "status"x ];then
    wecho "不支持的操作类型  '${operate}' "
    exit 1
  fi
}


# 第一个参数，是否操作主机
# 第二个参数，从机列表
# 第三个参数，第二主机  (其实可以为是否操作第二主机)
# 第四个参数，服务列表
start_arg()
{
  _include_master=${1}
  _hostlist=${2}
  _second_namenode=${3}
  _servicelist=${4}

  show_service_operate "start" "${_include_master}" "${_hostlist}" "${_second_namenode}" "${_servicelist}"

  # 5个参数必须全，这样可以大大简化代码
  echo "${_servicelist}" | grep -q "\<zookeeper\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      start_zookeeper_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       start_zookeeper_remote ${host}
      done
    fi
  fi

  echo "${_servicelist}" | grep -q "\<hadoop\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      start_hadoop_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       start_hadoop_remote ${host}
      done
    fi
    if [ -n "${_second_namenode}"  ]; then
      start_secondary_namenode ${_second_namenode}
    fi
  fi

  echo "${_servicelist}" | grep -q "\<hive\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      start_hive_local
    fi
  fi

  echo "${_servicelist}" | grep -q "\<petabase\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      start_petabase_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       start_petabase_remote ${host}
      done
    fi
  fi

  return 0

}

stop_arg()
{
  _include_master=${1}
  _hostlist=${2}
  _second_namenode=${3}
  _servicelist=${4}

  show_service_operate "stop" "${_include_master}" "${_hostlist}" "${_second_namenode}" "${_servicelist}"

  echo "${_servicelist}" | grep -q "\<petabase\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      stop_petabase_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       stop_petabase_remote ${host}
      done
    fi
  fi

  echo "${_servicelist}" | grep -q "\<hive\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      stop_hive_local
    fi
  fi

  echo "${_servicelist}" | grep -q "\<hadoop\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      stop_hadoop_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       stop_hadoop_remote ${host}
      done
    fi
    if [ -n "${_second_namenode}"  ]; then
      stop_secondary_namenode ${_second_namenode}
    fi
  fi

  echo "${_servicelist}" | grep -q "\<zookeeper\>"
  if [ $? -eq 0 ];then
    if [ "${_include_master}"x = "是"x ]; then
      stop_zookeeper_local
    fi
    if [ -n "${_hostlist}" ];then
      for host in ${_hostlist[@]};
      do
       stop_zookeeper_remote ${host}
      done
    fi
  fi

  return 0

}


operate_start()
{

  cat <<EOF
      petabse 4 个组件的启动是有依赖关系的，一般来说是zookeeper-->hadoop-->hive-->petabase的顺序

      即 如果hive相关没有正确启动，petabase服务是无法启动的(比如catalog)
      但 其中少许一些服务如(datanode)没有正确启动，又不会影响后面的服务

      总之
      如果不清楚他们之间的依赖关系，这里不建议您指定特定的服务进行控制 直接使用  ./petabase-service.sh 是最好的选择
      当然，如果您非常清楚他们之间的关系，登录到相应的机器进行控制也是非常好的选择

      建议您在执行本操作前，首先使用 ./petabase-service.sh status 来查看相应的状态
EOF

     iecho "输入 'YES' 以确认继续操作"
     read  TOGO
     if [ ${TOGO}x != "YES"x ];then
       exit 0;
     fi

    if [[ -z "${servicelist}" ]] && [[ -z "${hostlist}" ]] && [[ -z "${second_namenode}" ]] && [[  "${include_master}" = "否" ]]; then
      # 使用DATANODES 和SECONDARY_NAMENODE 来控制所有服务
      iecho "操作所有主机所有服务"
      start_arg "是" "${DATANODES}" "${SECONDARY_NAMENODE}"  "${SERVICE_LIST}"

    # 指定了服务 且指定了任意一种主机
    elif [[ -n "${servicelist}" ]] && [[ -n "${hostlist}" ]] || [[ -n "${second_namenode}" ]] || [[ "${include_master}" = "是" ]] ;then 
      start_arg "${include_master}" "${hostlist}" "${second_namenode}"  "${servicelist}"


    # 没有指定服务  肯定指定了一中类型的主机
    elif [[ -z "${servicelist}" ]];then
      start_arg "${include_master}" "${hostlist}" "${second_namenode}"  "${SERVICE_LIST}"


    # 仅仅指定了服务
    elif [[ "${include_master}" = "否" ]] && [[ -z "${hostlist}" ]] && [[ -z "${second_namenode}" ]];then 
      start_arg "是" "${DATANODES}" "${SECONDARY_NAMENODE}"  "${servicelist}"

    else
      echo "不支持的参数形式，请联系管理员"

    fi
    return 0

}


operate_stop()
{

    if [[ -z "${servicelist}" ]] && [[ -z "${hostlist}" ]] && [[ -z "${second_namenode}" ]] && [[ "${include_master}" = "否" ]]; then
      # 使用DATANODES 和SECONDARY_NAMENODE 来控制所有服务
      stop_arg "是" "${DATANODES}" "${SECONDARY_NAMENODE}"  "${SERVICE_LIST}"

    # 指定了服务 且指定了任意一种主机
    elif [[ -n "${servicelist}" ]] && [[ -n "${hostlist}" ]] || [[ -n "${second_namenode}" ]] || [[ "${include_master}" = "是" ]] ;then 
      stop_arg "${include_master}" "${hostlist}" "${second_namenode}"  "${servicelist}"


    # 没有指定服务  肯定指定了一中类型的主机
    elif [[ -z "${servicelist}" ]];then
      stop_arg "${include_master}" "${hostlist}" "${second_namenode}"  "${SERVICE_LIST}"


    # 仅仅指定了服务
    elif [[ "${include_master}" = "否" ]] && [[ -z "${hostlist}" ]] && [[ -z "${second_namenode}" ]];then 
      stop_arg "是" "${DATANODES}" "${SECONDARY_NAMENODE}"  "${servicelist}"

    else
      echo "不支持的参数形式，请联系管理员"

    fi
    return 0

}

# status命令直接查看所有机器的服务运行情况，部署人员配合grep使用即可分开查看
operate_status()
{
     status_zookeeper 
     status_hadoop 
     status_secondary_namenode "${SECONDARY_NAMENODE}"
     status_hive 
     status_petabase
}
######################################################################################

TEMP=`getopt -o n:d:s:f:mhz:: -l nodes:,secondary-namenode:,nodes-file:,master,service:,help,z-long \
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

     -m|--master)
       include_master="是"
       shift ;;

     -d|--service)
       IFS=','; servicelist=$2;
       echo "Option $1's argument is $servicelist"; 
       shift 2 ;;

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

construct_host_info

operate=${1}

arg_check
if [ $? = 1 ];then
  exit 1
fi



if [ -n "${operate}" ]; then
  if [ "${operate}"x = "start"x ]; then
    operate_start
    if [ $? = 1 ];then
      exit 1
    fi

  elif [ "${operate}"x = "stop"x ]; then
    operate_stop
    if [ $? = 1 ];then
      exit 1
    fi


  elif [ "${operate}"x = "restart"x ]; then
    operate_stop
    if [ $? = 1 ];then
      exit 1
    fi
    operate_start
    if [ $? = 1 ];then
      exit 1
    fi


  elif [ "${operate}"x = "status"x ]; then
     operate_status

  else
    echo "invalid type arguments"
  fi
else
  echo "please enter arguments completely"
fi
