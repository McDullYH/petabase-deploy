#!/usr/bin/python
# -*- coding:utf-8 -*-

#configuration.raw 是什么都没有填写的初始配置文件
#configuration.ripe 是什么部署环境自定义的配置文件
#configuration.tmp 是临时配置文件，用于在更换配置文件的时候存放新的配置，最后会写回ripe


# import xml.etree.ElementTree as ET

# need to put bs4 folder if you are not install bs4
from bs4 import BeautifulSoup as bs
from bs4.element import Tag
import sys
import re


# all impala configure file has following format, it has a name and value tag pair
#<configuration>
#<property>
#<name>dfs.datanode.hdfs-blocks-metadata.enabled</name>
#<value>true</value>
#</configuration>

# remember that print will output a var for shell, so all info will output in stderr

NAME='name'
VALUE='value'

def print_error(err_info):
    print>>sys.stderr,err_info



class XMLConfigurator():
    def __init__(self,file_path=None):
        if file_path==None:
            pass
        with open(file_path,'r') as f:
            self.soup=bs(f.read(),"xml")
        self.file_path=file_path

    def getProperty(self,name):
        if type(name)!=str:
            print_error('key must be str')
            return False
        ele=self.soup.find(name=NAME,text=name)
        if ele==None:
            return None
        else:
            #print "get succed it"
            # text and string is all OK, but text is used by BS4, string is used by you
            # return ele.parent.find(VALUE).text
            return ele.parent.find(VALUE).string

    # if has the property, change it, else create it
    def setProperty(self,name,value):
        if type(name)!=str or type(value)!=str:
            print_error('key and value must be str')
            return False
        if not verify(name,value):
            return False
        ele=self.soup.find(name=NAME,text=name)
        if ele==None:
            #print "create it"
            p=Tag(name='property')
            n=Tag(name=NAME)
            n.string=name
            v=Tag(name=VALUE)
            v.string=value
            p.append(n)
            p.append(v)
            configuration_tag=self.soup.find('configuration')
            configuration_tag.append(p)
        else:
            ele.parent.find(VALUE).string=value
            #print "set succed it"
        return True
    def write(self,output_path='output.xml'):
        with open(output_path,'w') as f:
            f.write(str(self.soup))


class ValidatorError(Exception):
    def __init__(self,value):
        self.value=value
    def __str__(self):
        return repr(self.value)

class RETester:
    def __init__(self,re_str,separator=None):
        if type(separator) == str and len(separator)>1:
            raise ValidatorError("seperator must be str and has size of 1")
        self.pattern=re.compile(re_str)
        self.separator=separator
    def set_separator(self,separator):
        if len(separator)>1:
            raise ValidatorError("seperator must be size of 1")
        self.separator=separator
        return self
        
    def __call__(self,source):
        if self.separator:
            for sub in source.split(self.separator):
                if not self.pattern.match(sub):
                    return False
        elif not self.pattern.match(source):
            return False
        return True

# must add $ at end!
boolean=RETester(r'([Tt]rue)$|([Ff]alse)$')
local_path=RETester(r'(\/([\w]+))+$')
file_path=RETester(r'file:\/\/(\/([\w]+))+$')
ip_port=RETester(r'[\w\-]+(:[\d]+)?$')


# use regular exp to validate the value
verifitor={'dfs.client.read.shortcircuit':boolean,
            'dfs.domain.socket.path':local_path,
            'dfs.datanode.data.dir':file_path.set_separator(','),
            'mapreduce.jobhistory.webapp.address':ip_port,
            }




def verify(name,value):
    #return verifitor[name.strip()](value.strip())
    if verifitor.get(name.strip())==None:
        return True
    if not verifitor[name.strip()](value.strip()):
        print("property '%s' is not valid for value '%s' "  % (name,value) )
    else:
        return True
    
    
# file is argv1
# key is setProperty 's first value
# value is setProperty 's second value

# Following class may should not to be a class, just for use 
# This may have a better design, now only do this for my poor py skills
# use __getattr__ may not reduce the source code, now

HADOOP_DIR="hadoop/"
NAMENODE_DIR="namenode/"
# TODO now has a 's',later will delete
DATANODE_DIR="datanodes/"
PETABASE_DIR="petabase/"
HIVE_DIR="hive/"
ZOOKEEPER_DIR="zookeeper/"

HDFS_XML="hdfs-site.xml"
CORE_XML="core-site.xml"
MAPRED_XML="mapred-site.xml"
HIVE_XML="hive-site.xml"
ZOO_CFG="zoo.cfg"

HOST_INFO_XML="host-info.xml"


src_configure_dir=None
dest_configure_dir=None

namenode=None
datanode_list=None

# now no use, later may use
second_namenode=None
mysql_root_passwd=None


# 这样处理应该有设计上的问题,所有的配置文件就一个
class NameNode:
    def __init__(self):
        self.hdfs_configure=XMLConfigurator(src_configure_dir+HADOOP_DIR+NAMENODE_DIR+HDFS_XML)
        self.mapred_configure=XMLConfigurator(src_configure_dir+HADOOP_DIR+NAMENODE_DIR+MAPRED_XML)
        self.core_configure=XMLConfigurator(src_configure_dir+HADOOP_DIR+NAMENODE_DIR+CORE_XML)
    def save(self):
        self.hdfs_configure.write(dest_configure_dir+HADOOP_DIR+NAMENODE_DIR+HDFS_XML)
        self.mapred_configure.write(dest_configure_dir+HADOOP_DIR+NAMENODE_DIR+MAPRED_XML)
        self.core_configure.write(dest_configure_dir+HADOOP_DIR+NAMENODE_DIR+CORE_XML)


class DataNode:
    def __init__(self):
        self.hdfs_configure=XMLConfigurator(src_configure_dir +  HADOOP_DIR +  DATANODE_DIR + HDFS_XML)
        self.mapred_configure=XMLConfigurator(src_configure_dir +  HADOOP_DIR + DATANODE_DIR + MAPRED_XML)
        self.core_configure=XMLConfigurator(src_configure_dir +  HADOOP_DIR + DATANODE_DIR + CORE_XML)
    def save(self):
        self.mapred_configure.write(dest_configure_dir + HADOOP_DIR + DATANODE_DIR + MAPRED_XML)
        self.core_configure.write(dest_configure_dir + HADOOP_DIR + DATANODE_DIR + CORE_XML)
        self.hdfs_configure.write(dest_configure_dir + HADOOP_DIR + DATANODE_DIR + HDFS_XML)

class Petabase:
    def __init__(self):
        self.hdfs_configure=XMLConfigurator(src_configure_dir + PETABASE_DIR + HDFS_XML)
        self.core_configure=XMLConfigurator(src_configure_dir + PETABASE_DIR + CORE_XML)
        self.hive_configure=XMLConfigurator(src_configure_dir + PETABASE_DIR + HIVE_XML)
    def save(self):
        self.hdfs_configure.write(dest_configure_dir + PETABASE_DIR + HDFS_XML)
        self.hive_configure.write(dest_configure_dir + PETABASE_DIR + HIVE_XML)
        self.core_configure.write(dest_configure_dir + PETABASE_DIR + CORE_XML)

class Hive:
    def __init__(self):
        self.hive_configure=XMLConfigurator(src_configure_dir + HIVE_DIR + HIVE_XML)
    def save(self):
        self.hive_configure.write(dest_configure_dir + HIVE_DIR + HIVE_XML)
        

class HostInfo:
    def __init__(self):
        self.host_info_configure=XMLConfigurator(HOST_INFO_XML)
    def getProperty(self,name):
        return self.host_info_configure.getProperty(name)
    def setProperty(self,name,value):
        return self.host_info_configure.setProperty(name,value)
    def save(self):
        self.host_info_configure.write(HOST_INFO_XML)

class ZooKeeper:
    src_file=None
    dest_file=None
    def open(self):
        self.src_file=open(src_configure_dir + ZOOKEEPER_DIR + ZOO_CFG,"r")
        self.dest_file=open(dest_configure_dir + ZOOKEEPER_DIR + ZOO_CFG,"w")
    def save(self):
        self.dest_file.write(self.src_file.read());
        i=1
        self.dest_file.write("server.%d=%s:2888:3888\n" % (i,namenode))
        i=i+1
        for datanode in datanode_list.split(','):
            self.dest_file.write("server.%d=%s:2888:3888\n" % (i,datanode))
            i=i+1
        self.src_file.close()
        self.dest_file.close()



def init_host_config():
    nn=NameNode()
    nn.hdfs_configure.setProperty(r'dfs.namenode.http-address',"%s:50070" % (namenode))
    nn.mapred_configure.setProperty(r'mapred.job.tracker',"%s:8021" % (namenode))
    nn.core_configure.setProperty(r'fs.defaultFS',"hdfs://%s:8020" % (namenode))

    dn=DataNode()
    dn.mapred_configure.setProperty(r'mapred.job.tracker',"%s:8021" % (namenode))
    dn.core_configure.setProperty(r'fs.defaultFS',"hdfs://%s:8020" % (namenode))

    pb=Petabase()
    pb.hdfs_configure.setProperty(r'dfs.namenode.http-address',"%s:50070" % (namenode))
    pb.hive_configure.setProperty(r'javax.jdo.option.ConnectionURL',
        "jdbc:mysql://%s:3306/hive_metastore?createDatabaseIfNotExist=true&amp;characterEncoding=utf8&amp;useUnicode=true" % (namenode))
    pb.hive_configure.setProperty(r'hive.metastore.uris',"thrift://%s:9083" % (namenode))
    pb.hive_configure.setProperty(r'hive.zookeeper.quorum',"%s,%s" % (namenode,datanode_list))
    pb.core_configure.setProperty(r'fs.defaultFS',"hdfs://%s:8020" % (namenode))

    h=Hive()
    h.hive_configure.setProperty(r'javax.jdo.option.ConnectionURL',
        "jdbc:mysql://%s:3306/hive_metastore?createDatabaseIfNotExist=true&amp;characterEncoding=utf8&amp;useUnicode=true" % (namenode))
    h.hive_configure.setProperty(r'hive.metastore.uris',"thrift://%s:9083" % (namenode))
    h.hive_configure.setProperty(r'hive.zookeeper.quorum',"%s,%s" % (namenode,datanode_list))
    h.hive_configure.setProperty(r'javax.jdo.option.ConnectionPassword',"%s" % (mysql_root_passwd))

    zk=ZooKeeper()
    zk.open()

    nn.save()
    dn.save()
    h.save()
    pb.save()
    zk.save()

# 升级(改变)配置，从ripe中读，写到tmp，然后写回ripe（直接调用cp操作即可），由bash进行后续的cp操作
def update_host_config(): 
    pass

def updete_host_info():
    pass

def init_host_info():
    pass

def get_host_info(name):
    hi=HostInfo()
    return hi.getProperty(name)

def set_host_info(name,value):
    hi=HostInfo()
    hi.setProperty(name,value)
    hi.save()

if __name__=='__main__':
    #c=XMLConfigurator(sys.argv[1])
    #c.setProperty(r'dfs.domain.socket.path','domain')
    #c.setProperty(r'dfs.domain.socket.path','/domain')
    #c.setProperty(r'dfs.datanode.data.dir','file')
    #c.setProperty(r'dfs.datanode.data.dir','/file')
    #c.setProperty(r'dfs.datanode.data.dir','file:///file,file:///file')
    #c.setProperty(r'dfs.datanode.data.dir','file:///file,file:///file/impala-shell')
    #c.setProperty(r'dfs.client.read.shortcircuit','FF')
    #c.setProperty(r'dfs.client.read.shortcircuit','Flse')
    #c.setProperty(r'dfs.client.read.shortcircuit','False')
    #c.setProperty(r'dfs.client.read.shortcircuit','True')
    #c.setProperty(r'mapreduce.jobhistory.webapp.address',':8080')
    #c.setProperty(r'mapreduce.jobhistory.webapp.address','impala-server1:')
    #c.setProperty(r'mapreduce.jobhistory.webapp.address','impala-server1')
    #c.setProperty(r'mapreduce.jobhistory.webapp.address','impala-server1:8080')
    #c.write()
    #print c.getProperty(r'dfs.namenode.name.dir')



    # 这里由于都是自己调用这个脚本，所以顺序自己清楚
    # 后续使用更科学的参数分析方法
    if sys.argv[1] == 'init':
        src_configure_dir='configuration.raw/'
        dest_configure_dir='configuration.ripe/'
        namenode=sys.argv[2]
        datanode_list=sys.argv[3]
        # now no use, later may use
        second_namenode=sys.argv[4]
        mysql_root_passwd=sys.argv[5]
        init_host_info()
        init_host_config()
    elif sys.argv[1] =='update':
        src_configure_dir='configuration.ripe/'
        dest_configure_dir='configuration.tmp/'
        namenode=sys.argv[2]
        datanode_list=sys.argv[3]
        # now no use, later may use
        second_namenode=sys.argv[4]
        mysql_root_passwd=sys.argv[5]
        update_host_info()
        update_host_config()
    elif sys.argv[1] == 'get':
        property_name=sys.argv[2]
        property_value=get_host_info(property_name)
        print property_value
        # can be done in init host info  and update host info
    elif sys.argv[1] == 'set':
        property_name=sys.argv[2]
        property_value=sys.argv[3]
        set_host_info(property_name,property_value)
    else:
        print_error("bad operator")
        
