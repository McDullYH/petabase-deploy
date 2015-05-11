#!/bin/bash

# TODO 先安装MapReduce V1  后期 进行YARN的安装
# TODO 安装完成之后是否需要生成一个文件，记录哪些是namenode，哪些是datanode等等，方便后期控制脚本操作

# 关于使用-ivh参数是否不好的问题:
# petabase的安装很复杂，依赖很多，推荐的方式是在在线环境下使用yum安装，自动解决依赖。
# 但这里，我们需要尽可能的在离线情况下安装，所以，在安装过程中不免出现缺失依赖的问题，
# 使用--nodeps很可能会出现某个软件安装好了，但是因依赖缺乏无法运行的事情，但这本身不是部署人员的问题，
# 所以，脚本编写人员清楚依赖关系，并保证各个软件的运行依赖正确安装即可，故此处使用--nodeps不会有问题，
# 如果出现问题，当属安装脚本的bug或者缺陷，应修复

# IFS 设置为了 ',' 并没有修改回来，这个是不好的实现，应该如下
#
# IFS_BAK=${IFS}
# do your thing
# IFS=${IFS_BAK}
# 但是，本脚本多次使用了 for host in hostlist，所以本脚本没有进行上面的操作
# 注意，若有 IFS=','  hostlist="1,2,3,4"   ,那么
# echo ${hostlist}   结果是  1 2 3 4
# echo "${hostlist}" 结果是  1,2,3,4



# import temp variable
source ./deploy_config.sh


# do it when successfully install, forbid to reinstall

CHECK=false
HELP=false
FILE=""
hostlist=""
second_namenode=""

# used for py arg

# use for check summary
namenode_deps_soft_dict=""
namenode_installed_soft_dict=""
secnamenode_installed_soft_dict=""
declare -A datanode_deps_soft_dict
declare -A datanode_installed_soft_dict


show_usage(){
  cat <<EOF

  usage: $0 COMMAND OPTIONS

  COMMAND CAN BE
  install	To intall the cluster
  uninstall	To unintall the cluster

  OPTIONS CAN BE:
  SPECIFY THE DATANODE
  	$0 {-n|--nodes} [datanode list] 
	The datanode list should be separated by ',', seems like host1,host2,host3

  SPECIFY THE SECOND NAMENODE
  	$0 {-s|--secondary-namenode} [second-namenode]
	The secondary namenode should be in the datanode list

  USE FILE TO SPECIFY THE DATANODE AND NAMENODE
  	$0 {-f|--nodes-file} [filepath]

  The file format must be like following:
  	eg:
  	#file specify the datanodes and the second-namenode
	datanode:
	esen-petabase-234,esen-petabase-235
	second-name-node:
	esen-petabase-234

  JUST DO CHECK NOT DO OPERATE
  	$0 {-c|--check} 
  
  SHOW THIS HELP
  	$0 {-h|--help} 


  e.g. $0 install -n esen-petabase-234,esen-petabase-235 -s esen-petabase-234
EOF
exit 1
}


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

generate_configure_file()
{
  iecho "开始生成配置文件"
  # 注意双引号不能省，特别是 hostlist的双引号
  python config-setter.py ${1} `hostname` "${hostlist}" "${second_namenode}"
}


# now install jdk by rpm
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
# 20150508开始使用 rpm.list的方式，更具合理性

# not use now
install_soft_namenode()
{

  echo "[Log] install begin on $MASTER_HOST"

# now install jdk by rpm
# install_jdk

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


# not use now
install_soft_datanodes()
{
  for host in ${hostlist[@]}; do
#    echo "[Log] install begin on $host"
#
#    echo "[Log] install jdk on $host"
#
#    # install jdk
#    ssh   $host  "mkdir -p /usr/java"
#    ssh   $host  "tar xzvf $COMMON_SOFT_DIR/jdk-7u45-linux-x64.tar.gz -C /usr/java/ 1>/dev/null 2>&1"
#    if [ $? -ne 0 ];then
#      eecho "Unable to install jdk $MASTER_HOST";
#      exit 0
#    fi
#    ssh   $host  "cat $COMMON_SOFT_DIR/java_env  >> /etc/profile"
#    ssh   $host  "source /etc/profile"


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

# not use now
install_secondarynamenode()
{

  for rpm_file in $SEC_NAMENODE_SOFT_DIR/*.rpm
  do
    check_and_install_remote $second_namenode $rpm_file 
  done

}


echo_check_summary()
{
  iecho  "\n\n本机的检查报告:"
  if [[ -n "${namenode_deps_soft_dict}" ]]; then
    echo "本机缺少必要依赖如下:"
    for deps_soft in ${namenode_deps_soft_dict};do
      echo "$deps_soft"
    done
    else
     echo "本机已经安装好所有依赖"
  fi



  if [[ -n "${namenode_installed_soft_dict}" ]]; then
    echo "本机已经安装如下组件:"
    for installed_soft in ${namenode_installed_soft_dict};do
      echo "$installed_soft"
    done
    else
     echo "本机环境干净，没有安装任何petabase组件"
  fi


  for host in ${hostlist[@]}; do
    iecho  "\n\n${host}的检查报告："
    if [[ -n "${datanode_deps_soft_dict[${host}]}" ]]; then
      echo "$host缺少必要依赖如下:"
    for deps_soft in ${datanode_deps_soft_dict[${host}]};do
      echo "${deps_soft}"
      # if host has install a newer version will also report it, is it a bug?
    done
    else
      echo "${host}已经安装好所有依赖"
    fi

    if [[ -n "${datanode_installed_soft_dict[${host}]}" ]]; then
    echo "$host已经安装如下组件:"
    for installed_soft in ${datanode_installed_soft_dict[${host}]};do
      echo "${installed_soft}"
      # if host has install a newer version it won't report it, is it a bug?
      # To fixed it, we can construct a software list to check the software installed in any version
    done
    else
     echo "${host} 环境干净，没有安装任何petabase组件"
    fi
  done


  iecho  "\n\n第二主机(${second_namenode})的检查报告:"
  if [[ -n "${secnamenode_installed_soft_dict}" ]]; then
    echo "第二主机安装了如下组件"
    for installed_soft in ${secnamenode_installed_soft_dict};do
      echo "$installed_soft"
    done
    else
     echo "第二主机环境干净，没有安装任何petabase组件"
  fi

  echo "如需解决依赖关系,请先执行预安装脚本之后再执行本脚本"
  echo "若已经安装某些组件,建议先使用卸载脚本卸载后运行本脚本"
}


check_soft_namenode()
{

  # TODO  fix jdk installed
  # install_jdk

  # 依赖包比较特殊，对版本要求不严苛，总的来说，会出现下面的情况
  # 没有安装依赖包，此时预安装脚本会保证安装
  # 安装了依赖包，但版本较旧，此时预安装脚本会帮助更新
  # 安装了依赖包，但版本较新，此时预安装脚本不更新，不做处理，认为新安装包能胜任现在的工作


  iecho "开始检查本机petabase 依赖的安装情况"
  for key in ${!NESS_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? = 1 ];then
      namenode_deps_soft_dict=${namenode_deps_soft_dict}"${NESS_SOFT_DICT[${key}]},"
    fi
  done

  iecho "开始检查本机petabase组件是否已经安装"
  for key in ${!COMMON_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`rpm -q ${key}`
      namenode_installed_soft_dict=${namenode_installed_soft_dict}"${installed_pkg_name},"
    fi
  done

  for key in ${!NAMENODE_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`rpm -q ${key}`
      namenode_installed_soft_dict=${namenode_installed_soft_dict}"${installed_pkg_name},"
    fi
  done

  for key in ${!EXT_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`rpm -q ${key}`
      namenode_installed_soft_dict=${namenode_installed_soft_dict}"${installed_pkg_name},"
    fi
  done

#  使用上面的方式更准确，不过要创建一个文件列表
#  iecho "开始检查本机petabase 依赖的安装情况"
#  for rpm_file in $NESS_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_local $pkgname 
#    if [ $? = 1 ];then
#      namenode_deps_soft_dict=${namenode_deps_soft_dict}",$pkgname"
#    fi
#  done
#
#
#  iecho "开始检查本机petabase组件是否已经安装"
#  for rpm_file in $NAMENODE_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_local $pkgname 
#    if [ $? = 0 ];then
#      namenode_installed_soft_dict=${namenode_installed_soft_dict}",$pkgname"
#    fi
#  done
#
#  for rpm_file in $COMMON_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_local $pkgname 
#    if [ $? = 0 ];then
#      namenode_installed_soft_dict=${namenode_installed_soft_dict}",$pkgname"
#    fi
#  done
#
#  for rpm_file in $EXT_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_local $pkgname 
#    if [ $? = 0 ];then
#      namenode_installed_soft_dict=${namenode_installed_soft_dict}",$pkgname"
#    fi
#  done
}



check_soft_datanodes()
{
  for host in ${hostlist[@]}; do

  iecho "开始检查${host} 上petabase 依赖的安装情况"
  for key in ${!NESS_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? = 1 ];then
      datanode_deps_soft_dict[${host}]=${datanode_deps_soft_dict[${host}]}"${NESS_SOFT_DICT[${key}]},"
    fi

  done

  iecho "开始检查${host} 上petabase组件是否已经安装"
  for key in ${!DATANODE_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`ssh ${host} rpm -q ${key}`
      datanode_installed_soft_dict[${host}]=${datanode_installed_soft_dict[${host}]}"${installed_pkg_name},"
    fi
  done


  for key in ${!COMMON_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`ssh ${host} rpm -q ${key}`
      datanode_installed_soft_dict[${host}]=${datanode_installed_soft_dict[${host}]}"${installed_pkg_name},"
    fi
  done



#  使用上面的方式更准确，不过要创建一个文件列表
#  iecho "开始检查${host} 上petabase 依赖的安装情况"
#  for rpm_file in $NESS_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_remote $host $pkgname 
#    if [ $? = 1 ];then
#      datanode_deps_soft_dict[${host}]=${datanode_deps_soft_dict[${host}]}",$pkgname"
#    fi
#  done
#
#
#  iecho "开始检查${host} 上petabase组件是否已经安装"
#  for rpm_file in $DATANODE_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_remote $host $pkgname
#    if [ $? = 0 ];then
#      datanode_installed_soft_dict[${host}]=${datanode_installed_soft_dict[${host}]}",$pkgname"
#    fi
#  done
#
#  for rpm_file in $COMMON_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_remote $host $pkgname 
#    if [ $? = 0 ];then
#      datanode_installed_soft_dict[${host}]=${datanode_installed_soft_dict[${host}]}",$pkgname"
#    fi
#  done

 done

}


check_soft_secondarynamenode()
{


  iecho "开始检查第二主机 ${second_namenode} 上petabase 相关组件是否已经安装"
  for key in ${!SEC_NAMENODE_SOFT_DICT[@]};do
    check_install_remote ${second_namenode} ${key}
    if [ $? = 0 ];then
      installed_pkg_name=`ssh ${second_namenode} rpm -q ${key}`
      secnamenode_installed_soft_dict=${secnamenode_installed_soft_dict}"${installed_pkg_name},"
    fi
  done

#  iecho "开始检查第二主机 ${second_namenode} 上petabase 相关组件是否已经安装"
#  for rpm_file in $SEC_NAMENODE_SOFT_DIR/*.rpm
#  do
#    pkgname=`basename $rpm_file .rpm`
#    check_install_remote $second_namenode $pkgname 
#    if [ $? = 0 ];then
#      datanode_installed_soft_dict[${second_namenode}]=${datanode_installed_soft_dict[${second_namenode}]}",$pkgname"
#    fi
#  done

}



#这个环境变量必须设置！！
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
  rm -rf /etc/hadoop/conf.my_cluster
  cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster
  alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50
  alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster

  # show info
  #alternatives --display hadoop-conf
  
  # datanodes
  for host in ${hostlist[@]}; do
    ssh  $host "rm -rf /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh  $host "cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster/" 1>/dev/null 2>&1
    ssh  $host "alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50" 1>/dev/null 2>&1
    ssh  $host "alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster" 1>/dev/null 2>&1

    # show info
    #ssh  $host "alternatives --display hadoop-conf"
  done
}

conf_namenode()
{
  # zookeeper
  cp -f ${CONFIGURATION_DIR}/zookeeper/zoo.cfg /etc/zookeeper/conf/zoo.cfg
  # hadoop
  cp -f ${CONFIGURATION_DIR}/hadoop/namenode/core-site.xml /etc/hadoop/conf.my_cluster/
  cp -f ${CONFIGURATION_DIR}/hadoop/namenode/hdfs-site.xml /etc/hadoop/conf.my_cluster/
  cp -f ${CONFIGURATION_DIR}/hadoop/namenode/mapred-site.xml /etc/hadoop/conf.my_cluster/

  # TODO no need?
  #cp -f ${CONFIGURATION_DIR}/hadoop/masters /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
  #cp -f ${CONFIGURATION_DIR}/hadoop/slaves /etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1

  cp -f ${CONFIGURATION_DIR}/hadoop/hadoop /etc/default/hadoop
  # hive
  cp -f ${CONFIGURATION_DIR}/hive/hive-site.xml /etc/hive/conf/
  # petabase
  sed -i "s/127.0.0.1/$MASTER_HOST/g" /etc/default/impala
  cp -f ${CONFIGURATION_DIR}/petabase/core-site.xml /etc/impala/conf/
  cp -f ${CONFIGURATION_DIR}/petabase/hdfs-site.xml /etc/impala/conf/
  cp -f ${CONFIGURATION_DIR}/petabase/hive-site.xml /etc/impala/conf/
}

conf_datanodes()
{
  for host in ${hostlist[@]}; do
    # zookeeper
    scp  /etc/zookeeper/conf/zoo.cfg $host:/etc/zookeeper/conf/ 
    # hadoop
    scp  ${CONFIGURATION_DIR}/hadoop/datanodes/core-site.xml $host:/etc/hadoop/conf.my_cluster/
    scp  ${CONFIGURATION_DIR}/hadoop/datanodes/hdfs-site.xml $host:/etc/hadoop/conf.my_cluster/
    scp  ${CONFIGURATION_DIR}/hadoop/datanodes/mapred-site.xml $host:/etc/hadoop/conf.my_cluster/

    # TODO no need?
    #scp  /etc/hadoop/conf.my_cluster/masters $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    #scp  /etc/hadoop/conf.my_cluster/slaves $host:/etc/hadoop/conf.my_cluster/ 1>/dev/null 2>&1
    scp  /etc/default/hadoop $host:/etc/default/
    ssh  $host "chown root:root /etc/default/hadoop"
    # hive
    scp  /etc/hive/conf/hive-site.xml $host:/etc/hive/conf/
    # petabase
    scp  /etc/default/impala $host:/etc/default/
    scp  /etc/impala/conf/core-site.xml $host:/etc/impala/conf/
    scp  /etc/impala/conf/hdfs-site.xml $host:/etc/impala/conf/
    scp  /etc/impala/conf/hive-site.xml $host:/etc/impala/conf/
    ssh  $host "chown -R root:root /etc/impala/conf"
    ssh  $host "chown root:root /etc/default/impala"
  done
}

prepare_use_hive()
{
  cp -f ${COMMON_SOFT_DIR}/mysql-connector-java-*.jar /usr/lib/hive/lib

  # TODO 貌似原来也没有这个文件，只是原来把输出重定向了...
  #cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib
  usermod -a -G hadoop petabase
  usermod -a -G hive petabase
  usermod -a -G hdfs petabase
  for host in ${hostlist[@]}; do
    ssh  $host "cp -f ${COMMON_SOFT_DIR}/mysql-connector-java-*.jar /usr/lib/hive/lib"

    # TODO 貌似原来也没有这个文件，只是原来把输出重定向了...
    #ssh  $host "cp -f /usr/lib/parquet/lib/parquet-hive*.jar /usr/lib/hive/lib"
    ssh  $host "usermod -a -G hadoop petabase"
    ssh  $host "usermod -a -G hive petabase"
    ssh  $host "usermod -a -G hdfs petabase"
  done
}


#后期这些可能会放到控制脚本的init命令里面
conf_haproxy()
{
 rm -f /etc/haproxy/haproxy.cfg
 cat HA.config.part1 >> /etc/haproxy/haproxy.cfg
 for host in ${hostlist[@]}; do
   echo "server ${host}_jdbc ${host}:21050" >>/etc/haproxy/haproxy.cfg
 done
 cat HA.config.part2 >> /etc/haproxy/haproxy.cfg
 for host in ${hostlist[@]}; do
   echo "server ${host}_shell ${host}:21000" >>/etc/haproxy/haproxy.cfg
 done
 service haproxy start
}


delete_group-user_namenode()
{
  userdel -r $PETA_USER 1>/dev/null 2>&1
  groupdel $PETA_GRP 1>/dev/null 2>&1
}

delete_group-user_datanode()
{
  for host in ${hostlist[@]}; do
    ssh  $host "userdel -r $PETA_USER" 1>/dev/null 2>&1
    ssh  $host "groupdel $PETA_GRP" 1>/dev/null 2>&1
  done
}

# not use now
uninstall_soft_namenode()
{
#  now install jdk by rpm in preinstall
#  echo "uninstall jdk on $MASTER_HOST"
#  rm -rf /usr/java
#  sed -i '/export JAVA_HOME=/'d /etc/profile
#  sed -i '/export JRE_HOME=/'d /etc/profile
#  sed -i '/export CLASSPATH=/'d /etc/profile
#  sed -i '/export PATH=/'d /etc/profile

  echo "uninstall software on $MASTER_HOST"

  for rpm_file in $NAMENODE_SOFT_DIR/*.rpm
  do
    check_and_uninstall_local $rpm_file
  done

  for rpm_file in $COMMON_SOFT_DIR/*.rpm
  do
    check_and_uninstall_local $rpm_file
  done

  for rpm_file in $EXT_SOFT_DIR/*.rpm
  do
    check_and_uninstall_local $rpm_file
  done


}

# not use now
uninstall_soft_datanodes()
{
  for host in ${hostlist[@]}; do

#    now install by rpm in preinstall
#    echo "uninstall jdk on $host"
#    ssh  $host "rm -rf /usr/java"
#    ssh  $host "sed -i '/export JAVA_HOME=/'d /etc/profile"
#    ssh  $host "sed -i '/export JRE_HOME=/'d /etc/profile"
#    ssh  $host "sed -i '/export CLASSPATH=/'d /etc/profile" 
#    ssh  $host "sed -i '/export PATH=/'d /etc/profile" 

    for rpm_file in $DATANODE_SOFT_DIR/*.rpm
    do
      check_and_uninstall_remote $host $rpm_file
    done

    for rpm_file in $COMMON_SOFT_DIR/*.rpm
    do 
      check_and_uninstall_remote $host $rpm_file
    done
  done

}

# not use now
uninstall_soft_secondarynamenode()
{

  for rpm_file in $SEC_NAMENODE_SOFT_DIR/*.rpm
    do
      check_and_uninstall_remote $second_namenode $rpm_file
    done
}


# 关联数组无法作为参数传入，故而只能逐个处理，无法抽象为函数
check_and_install_namenode_from_rpm_list()
{
  for key in ${!COMMON_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`rpm -q ${key}`
      pkgname=`basename ${COMMON_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_local ${COMMON_SOFT_DIR}/${COMMON_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在本机安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done


  for key in ${!NAMENODE_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`rpm -q ${key}`
      pkgname=`basename ${NAMENODE_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_local ${NAMENODE_SOFT_DIR}/${NAMENODE_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在本机安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done

  for key in ${!EXT_SOFT_DICT[@]};do
    check_install_local ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`rpm -q ${key}`
      pkgname=`basename ${EXT_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_local ${EXT_SOFT_DIR}/${EXT_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在本机安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done

  return 0
}

check_and_install_datanode_from_rpm_list()
{

 for host in ${hostlist[@]}; do
  for key in ${!COMMON_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`ssh ${host} rpm -q ${key}`
      pkgname=`basename ${COMMON_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "${host}已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "${host}已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_remote ${host} ${COMMON_SOFT_DIR}/${COMMON_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在${host}安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done

  for key in ${!DATANODE_SOFT_DICT[@]};do
    check_install_remote ${host} ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`ssh ${host} rpm -q ${key}`
      pkgname=`basename ${DATANODE_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "${host}已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "${host}已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_remote ${host} ${DATANODE_SOFT_DIR}/${DATANODE_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在${host}安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done
 done
 return 0
}

check_and_install_secnamenode_from_rpm_list()
{
  for key in ${!SEC_NAMENODE_SOFT_DICT[@]};do
    check_install_remote ${second_namenode} ${key}
    if [ $? -eq 0 ]; then
      installed_pkg_name=`ssh ${second_namenode} rpm -q ${key}`
      pkgname=`basename ${SEC_NAMENODE_SOFT_DICT[${key}]} .rpm`
      if [ ${installed_pkg_name}x = ${pkgname}x  ];then
   	iecho "${second_namenode}已经安装${installed_pkg_name}，不需要再次安装"
      else
        wecho "${second_namenode}已经安装了不同版本的包${installed_pkg_name},请卸载后重新执行本脚本"
	exit 1
      fi
    else
      install_soft_remote ${second_namenode} ${SEC_NAMENODE_SOFT_DIR}/${SEC_NAMENODE_SOFT_DICT[${key}]}
      if [ $? -ne 0 ]; then
        eecho "在${second_namenode}安装${pkgname}失败，请检查相关日志"
        exit 1
      fi
    fi
  done
 return 0
}


# 不用做任何检查，直接卸载即可
uninstall_namenode_from_rpm_list()
{

  for key in ${!NAMENODE_SOFT_DICT[@]};do
    uninstall_soft_local ${key}
  done

  for key in ${!COMMON_SOFT_DICT[@]};do
    uninstall_soft_local ${key}
  done

  for key in ${!EXT_SOFT_DICT[@]};do
    uninstall_soft_local ${key}
  done
  return 0
}

uninstall_datanode_from_rpm_list()
{

 for host in ${hostlist[@]}; do
  for key in ${!COMMON_SOFT_DICT[@]};do
    uninstall_soft_remote ${host} ${key}
  done


  for key in ${!DATANODE_SOFT_DICT[@]};do
    uninstall_soft_remote ${host} ${key}
  done

 done
 return 0
}

uninstall_secnamenode_from_rpm_list()
{
  for key in ${!SEC_NAMENODE_SOFT_DICT[@]};do
    uninstall_soft_remote ${second_namenode} ${key}
  done
 return 0
}



arg_check()
{

  if [ ${operate}x = ""x ];then
    wecho "请指定一个操作类型 install/uninstall"
    exit 1
  elif [ ${operate}x != "install"x ] && [ ${operate}x != "uninstall"x ] && [ ${operate}x != "check"x ];then
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
}

show_operate()
{
  iecho "操作类型:	${operate}"
  iecho "从机列表:	${hostlist}"
  iecho "第二主机:	${second_namenode}"

  iecho "输入 'YES' 将继续操作"
  read  TOGO
  if [ ${TOGO}x = "YES"x ];then
    return 0;
  else
    iecho "操作取消"
    return 1;
  fi

}


######################################################################################

# first analsyse argument
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
       echo "Option $1's argument is $hostlist"; 
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

if [ ${operate}x = "install"x ];then
  iecho "`date +%Y%m%d-%T` install begin"
  generate_configure_file init
  iecho "check user and group"
  check_user-group
  check_user-group_slaves
  iecho "install software"

  # old way
  #install_soft_namenode
  #install_soft_datanodes
  #install_secondarynamenode
  check_and_install_namenode_from_rpm_list
  check_and_install_datanode_from_rpm_list
  check_and_install_secnamenode_from_rpm_list

  iecho "configure software"
  # bigtop 是 cdh的依赖
  conf_bigtop-utils
  prepare_use_hadoop
  prepare_use_hive
  conf_namenode
  conf_datanodes
  conf_haproxy
  iecho "`date +%Y%m%d-%T` finish"

elif [ ${operate}x = "uninstall"x ];then
  iecho "`date +%Y%m%d-%T` uninstall begin"
  iecho "delete user and group"
  delete_group-user_namenode
  delete_group-user_datanode

  iecho "uninstall software"
  uninstall_namenode_from_rpm_list
  uninstall_datanode_from_rpm_list
  uninstall_secnamenode_from_rpm_list

  #uninstall_soft_namenode
  #uninstall_soft_datanodes
  #uninstall_soft_secondarynamenode
  iecho "`date +%Y%m%d-%T` finish"
elif [ ${operate}x = "check"x ];then
  iecho "`date +%Y%m%d-%T` check begin"
  check_soft_namenode
  check_soft_datanodes
  check_soft_secondarynamenode
  echo_check_summary
else
  echo "目前还不支持  ${operate}  操作..."
  exit 1;
fi
