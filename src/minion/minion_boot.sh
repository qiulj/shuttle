#!/bin/bash
set -x
set -o pipefail

CmdArgs=$*

HADOOP_CLIENT_HOME=/tmp/hadoop-client

IsValidHadoop() {
	if [ ! -f ${HADOOP_CLIENT_HOME}/hadoop/libhdfs/libhdfs.so ]; then
		return 1
	fi
	lib_so_count=`ls ${HADOOP_CLIENT_HOME}/hadoop/lib/native/Linux-amd64-64/ | wc -l`
	if [ $lib_so_count -ne 19 ]; then
		return 2
	fi
	return 0
}

DownloadHadoop() {
	IsValidHadoop
	if [ $? -ne 0 ]; then
		./NfsShell get /disk/shuttle/hadoop-client.tar.gz ./hadoop-client.tar.gz
		if [ $? -ne 0 ]; then
			return 1
		fi
		tar -xzf hadoop-client.tar.gz
		if [ $? -ne 0 ]; then
			return 2
		fi
		IsValidHadoop
		if [ $? -ne 0 ]; then
			rm -rf ${HADOOP_CLIENT_HOME}
			mv ./hadoop-client /tmp/
			return $?
		fi
	fi
	return 0
}

DownloadMinionTar() {
	./NfsShell get /disk/shuttle/minion.tar.gz minion.tar.gz
	return $?
}

ExtractMinionTar() {
	tar -xzf minion.tar.gz
	ret=$?
	mv -f ./hadoop-site.xml $HADOOP_CLIENT_HOME/hadoop/conf/
	return $ret
}

DownloadUserTar() {
	if [ "$app_package" == "" ]; then
		echo "need app_pacakge"
		return -1
	fi
	for ((i=0;i<5;i++))
	do
		cache_archive=$( eval echo \$cache_archive_${i} )
		if [ "$cache_archive" != "" ]; then
			cache_archive_addr=`echo $cache_archive | cut -d"#" -f 1`
			cache_archive_dir=`echo $cache_archive | cut -d"#" -f 2`
			if [ "$cache_archive_dir" == "" ]; then
				return -1
			fi
			mkdir $cache_archive_dir
			rm -f $cache_archive_dir/*.tar.gz
			${HADOOP_CLIENT_HOME}/hadoop/bin/hadoop fs -get $cache_archive_addr $cache_archive_dir
			if [ $? -ne 0 ]; then
				return -1
			fi
			(cd $cache_archive_dir && (tar -xzf *.tar.gz; tar -xf *.tar))
		else
			break
		fi
	done
	local_package=`echo $app_package | awk -F"/" '{print $NF}'`
	./NfsShell get /disk/shuttle/${app_package} ${local_package}
	return $?	
}

ExtractUserTar() {
	tar -xzf ${local_package}
	return $?
}

StartMinon() {
	source hdfs_env.sh > /dev/null 2>&1
	ls . | grep -v '^log$' > common.list
	if [ $? -ne 0 ]; then
		return 1
	fi
	./minion $CmdArgs
	return $?
}

CheckStatus() {
	ret=$1
	msg=$2
	if [ $ret -ne 0 ]; then
		echo $msg
		sleep 60
		exit $ret
	fi
}

DownloadHadoop
CheckStatus $? "download hadoop fail"

DownloadMinionTar
CheckStatus $? "download minion package from DFS fail"

ExtractMinionTar
CheckStatus $? "extract minion package fail"

DownloadUserTar
CheckStatus $? "download user package fail"

ExtractUserTar
CheckStatus $? "extract user package fail"

StartMinon
CheckStatus $? "minion exit without success"

echo "=== Done ==="
