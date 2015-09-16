﻿shuttle框架设计
====

## 设计背景
Galaxy是一个集群调度和管理系统，可以将用户程序部署在集群上运行。同时Galaxy仍需要一个基于Map Reduce框架的流式计算模型，以便用户可以在Galaxy上直接进行Map Reduce框架的批处理任务而不需要额外的配置。基于此目的我们设计了shuttle。

## 需求分析
1. 基于Galaxy
该计算框架基于Galaxy调度系统，依靠Galaxy集群进行资源分配和任务管理。
2. 松耦合于现有分布式文件系统
计算框架的输入输出应当支持从现有的分布式文件系统，如HDFS上，读取写入数据。

## 设计思路
设计整体思路如下图。  
1. 主从式结构部署  
shuttle利用一个全局唯一的master来接受用户提交的请求，并利用Galaxy提供的sdk开启minion来控制管理用户的Map和Reduce批处理任务。minion负责管理批处理任务的输入和输出，并将运行状况汇报给master。  
2. 利用HDFS缓存中间结果  
shuttle负责将Map的输出排序后发送给Reduce。为了支持大规模数据的处理，因此我们采取将Map的中间输出暂存至HDFS的方法，来应付大规模的数据，减少对内存的压力，以在Galaxy上获取更多的槽位。  
3. 包管理  
minion除负责提供输入处理输出外还具有包管理的功能。用户使用客户端提交的运行所需要的文件不是一开始打包给Galaxy，而是暂存在HDFS上，当minion启动运行批处理任务前，会将这些文件从HDFS获取至本地。如编写wordcount程序，用户提供的待统计的文本就暂存在HDFS上。  

    +--------+                   +--------+                 +-------------+
    | master | -- submit job --> | Galaxy | -- schedule --> | minion(Map) | -+
    +--------+                   +--------+                 +-------------+  |             +------+
         |                            |                                      +- sorted --> | HDFS |
         |            +-------+       |                                                    +------+
         +-- meta --> | nexus |       |                +----------------+                      |
                      +-------+       +-- schedule --> | minion(Reduce) | <----- data ---------+
                                                       +----------------+
