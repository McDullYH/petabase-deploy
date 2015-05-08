#!/bin/bash
# 先安装MapReduce V1  后期 进行YARN的安装

real_usr="`whoami`"
check_usr="root"
if [ "${real_usr}" != "${check_usr}" ]; then
  echo "The user must be $check_usr"
  exit 0
fi



#if [ -e "./ssh_config" ];then
#  SSH_ARGS="-F ./ssh_config"
#fi

# import temp variable
source ./deploy_config.sh


CHECK=false
HELP=false
FILE=""
hostlist=""


copy_esen_software()
{
for host in ${hostlist[@]}; do
  echo "Copying software to $host"
  ssh ${SSH_ARGS} $host "mkdir -p $ESEN_PETA/" 1>/dev/null 2>&1
  rsync -avzu --progress $COMMON_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $COMMON_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $DATANODE_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $DATANODE_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $SEC_NAMENODE_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $SEC_NAMENODE_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

  rsync -avzu --progress $NESS_SOFT_DIR $host:$ESEN_PETA/ 1>/dev/null 2>&1
    if [ $? -ne 0 ];then
      eecho "Unable to copy $NESS_SOFT_DIR/ to $host:$ESEN_PETA"
      exit 0
    fi

done
}


install_necessary_soft_namenode()
{

  echo "[Log] preinstall begin on $MASTER_HOST"

  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
    check_and_install_local $rpm_file
    if [ $? -ne 0 ];then
      return 1
    fi
  done
}


install_necessary_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    echo "[Log] $host 启动预安装"

  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
    check_and_install_remote $host $rpm_file
    if [ $? -ne 0 ];then
      return 1
    fi
    done
 done

}

check_and_install_necessary_namenode_from_rpm_list()
{
  for key in ${!NESS_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`rpm -q ${key}`
      pkgname=`basename ${NESS_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "已经安装了不同版本的包${installed_pkg_name},正尝试升级..."
	rpm -U   ${NESS_SOFT_DIR}/${NESS_SOFT_DICT[${key}]} 2>&1 |grep "which is newer" 1>/dev/null 2>&1
	if [ $? == 0 ];then
	  iecho "本机的${key}版本更新，无需升级"
	else
	  echo "升级本机${key}成功"
	fi
      fi
     else
      install_soft_local ${NESS_SOFT_DIR}/${NESS_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在本机安装${pkgname}失败，请检查相关日志"
        return 1
      fi
    fi
  done

  return 0
}

check_and_install_necessary_datanode_from_rpm_list()
{

 for host in ${hostlist[@]}; do
  for key in ${!NESS_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`ssh ${host} rpm -q ${key}`
      pkgname=`basename ${NESS_SOFT_DICT[${key}]} .rpm`
      echo ${installed_pkg_name}
      echo ${pkgname}
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "${host}已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "${host}已经安装了不同版本的包${installed_pkg_name},正尝试升级..."
	ssh ${host} "rpm -U   ${NESS_SOFT_DIR}/${NESS_SOFT_DICT[${key}]} 2>&1 |grep 'which is newer' 1>/dev/null 2>&1"
	if [ $? == 0 ];then
	  iecho "${host}的${key}版本更新，无需升级"
	else
	  echo "升级${host}的${key}成功"
	fi
      fi
      else
      install_soft_remote ${host} ${NESS_SOFT_DIR}/${NESS_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在${host}安装${pkgname}失败，请检查相关日志"
        return 1
      fi
    fi
  done
 done
 return 0
}





uninstall_necessary_soft_namenode()
{
  for rpm_file in $NESS_SOFT_DIR/*.rpm
    do
      pkgname=`basename $rpm_file .rpm`
      echo "uninstalling $pkgname"
      rpm -e --nodeps ${pkgname} 1>/dev/null 2>&1
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall ${pkgname} on $MASTER_HOST"
      fi
  done
}


uninstall_necessary_soft_datanodes()
{
  for host in ${hostlist[@]}; do
    for rpm_file in $NESS_SOFT_DIR/*.rpm
      do 
        pkgname=`basename $rpm_file .rpm`
        echo "uninstalling $pkgname on $host"
        ssh   $host    "rpm -e --nodeps ${pkgname} 1>/dev/null 2>&1"
        if [ $? -ne 0 ];then
          eecho "Unable to uninstall ${pkgname} to $host"
        fi
      done
  done

}



ssh_auth()
{
  ssh-keygen -t rsa;
  for host in ${hostlist[@]};do
    echo "auth for $host"
    ssh-copy-id $host
  done
}

install_mysql()
{

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-common-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-common to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi
      
  rpm -ivh --replacefiles $MYSQL_SOFT_DIR/mysql-community-libs-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-libs to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-client-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-client to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/perl-DBI-1.609-4.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-perl-DBI to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

  rpm -Uvh --replacefiles $MYSQL_SOFT_DIR/mysql-community-server-5.6.23-2.el6.x86_64.rpm
      if [ $? -ne 0 ];then
        eecho "无法安装 $mysql-community-server to $MASTER_HOST,请检查是不是先前版本的mysql没有删除干净，或者已经运行了本预安装程序"
      fi

}


configure_mysql()
{
  service mysqld start
  chkconfig mysqld on
  sleep 7
  /usr/bin/mysql_secure_installation

  # 注意 Disallow root login remotely? 选择 n

}

uninstall_mysql()
{
  rpm -e mysql-community-server-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-server to $MASTER_HOST"
      fi
  rpm -e mysql-community-client-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-client to $MASTER_HOST"
      fi
  rpm -e mysql-community-libs-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-libs to $MASTER_HOST"
      fi
  rpm -e mysql-community-common-5.6.23-2.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-common to $MASTER_HOST"
      fi
  rpm -e perl-DBI-1.609-4.el6.x86_64
      if [ $? -ne 0 ];then
        eecho "Unable to uninstall mysql-community-perl-DBI to $MASTER_HOST"
      fi

  #删除数据
  rm -rf /var/lib/mysql
  #删除表
  rm -f /etc/my.cnf
}


# 201504xx TODO 目前仅仅禁用本机的防火墙和selinux,没有问题，若发现问题，再来定位
# 20150423  每个host的iptables必须关闭
configure_iptables()
{
  service iptables stop;
  chkconfig iptables off;
for host in ${hostlist[@]}; do
  ssh $host "service iptables stop"
  ssh $host "chkconfig iptables off"
done
}


configure_selinux()
{
  cp selinux_config /etc/selinux/config
  setenforce 0
}


check_install_redhat-lsb()
{
  check_install_local redhat-lsb
  if [ $? = 1 ];then
    wecho "必须为本机安装redhat-lsb"
    wecho "请运行yum install -y redhat-lsb后再次执行本预安装脚本"
    exit 1
  fi

  for host in ${hostlist[@]}; do
    check_install_remote $host redhat-lsb
    if [ $? = 1 ];then
      wecho "必须为$host安装redhat-lsb"
      wecho "请为$host运行yum install -y redhat-lsb后再次执行本预安装脚本"
      exit 1
    fi
  done
}

check_install_mysql()
{
  rpm -qa |grep -i mysql 1>/dev/null 2>&1
  if [ $? = 0 ];then
    wecho "本机存在已经安装的mysql，请在备份数据后删除，然后再运行本预安装程序"
    echo "您可以使用 'rpm -qa |grep -i mysql' 来查找已经安装的mysql包"
    echo "并使用rpm -e <package_name> 来卸载该包"
    exit 1
  else
    return 0
  fi
}


#############################################################################

# first analsyse argument
TEMP=`getopt -o n:s:f:chz:: -l nodes:,secondary-namenode:,nodes-file:,check,help,z-long \
     -n '错误的输入参数' -- "$@" `

if [ $? != 0 ] ; then echo "退出..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

arg_check()
{

  if [[ -z "${hostlist}" ]];then
    wecho "请指定从机列表"
    return 1
  fi

}

show_operate()
{
  iecho "从机列表:	${hostlist}"

  iecho "输入 'YES' 将继续操作"
  read  TOGO
  if [ ${TOGO}x = "YES"x ];then
    return 0;
  else
    iecho "操作取消"
    return 1;
  fi

}


while true ; do
  case "$1" in
# c 和 h 选项是没有参数的，如果使用了$2，会直接取下一个参数
     -n|--nodes) 
       IFS=','; hostlist=$2;
       #echo "Option $1's argument is $hostlist"; 
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
	 if [ ${LINE}x = "datanode:"x ];then
	 read LINE
         IFS=','; hostlist=$LINE;
	 fi
	 done  <${FILE}
       shift 2 ;;

     -c|--check) 
       $CHECK=true; 
       echo "Option $1's argument is $CHECK" ; 
       shift ;;

     -h|--help)  
       $HELP=true;  
       echo "Option $1's argument is $HELP" ; 
       shift ;;

 # 这里预留一个可选参数的使用方法，方便扩展
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



arg_check
if [ $? = 1 ];then
  exit 1
fi


echo "`date +%Y-%m-%d-%T`开始预安装"

#echo "检查文件完整性"
#check_file

#iecho "配置SSH"
#ssh_auth

check_install_redhat-lsb
#check_install_mysql

iecho "正在拷贝组件到其他节点"
copy_esen_software

iecho "安装必要软件"
check_and_install_necessary_namenode_from_rpm_list
#install_necessary_soft_namenode
if [ $? -ne 0 ];then
 eecho "主机上安装必要软件失败，退出"
 exit 1
fi


check_and_install_necessary_datanode_from_rpm_list
#install_necessary_soft_datanodes
if [ $? -ne 0 ];then
 eecho "从机上安装必要软件失败，退出"
 exit 1
fi

iecho "安装mysql server"
install_mysql

iecho "配置mysql"
configure_mysql

iecho "禁止iptables 启动"
configure_iptables

iecho "禁止selinux 启动"
configure_selinux

 #for test script never use
 #uninstall_mysql
 #uninstall_necessary_soft_namenode
 #uninstall_necessary_soft_datanodes

iecho "`date +%Y-%m-%d-%T` 完成"
