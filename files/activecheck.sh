#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Controls the ActiveCheck application
#
# chkconfig: 345 98 2
# description: Checks all configured services
# processname: activecheck
#

# import system functions
. /etc/init.d/functions

# get Parameters
action="$1"

# defaults
app_name="activecheck"
app_cfgdir="/etc/activecheck"
app_cfgddir="${app_cfgdir}/conf.d"
app_cfgfile="${app_cfgdir}/activecheck.cfg"
app_logcfg="${app_cfgdir}/logback.xml"
app_logfile="/var/log/${app_name}.log"
app_pidfile="/var/run/${app_name}.pid"
app_jarfile="/usr/share/activecheck/activecheck.jar"
app_jmxpwd="${app_cfgdir}/jmxremote.password"
app_jmxacl="${app_cfgdir}/jmxremote.access"

cmd_java="/usr/bin/java"
initwait=5
killwait=5
rundate=$(date)

# source additional configuration
if [ -f "/etc/sysconfig/activecheck" ] ; then
  . /etc/sysconfig/activecheck
elif [ -f "/etc/default/activecheck" ] ; then
  . /etc/default/activecheck
fi

# sanity checks
for file in ${cmd_java} ${app_cfgdir} ${app_cfgfile} ${app_jarfile} ; do
  if [ ! -e "${file}" ] ; then
    echo "File/Path '${file}' is missing! Aborting."
    exit 1
  fi
done


#
# get pid for a component
#
# @param $1 rewrite app_pidfile <true|false>
#
getPidForComponent() {
  local force=${1:-false}
  local pid=-1

  if ! pid=$(pidofproc -p "${app_pidfile}") || [ "${force}" == "true" ] ; then
    # if pid cannot be found try to determine
    pid=$(ps auxwww | grep -e "${cmd_java}[[:blank:]].*${app_jarfile}" | grep -v grep | awk '{ print $2 }')
  fi

  if ! checkpid ${pid} ; then
    rm -f ${app_pidfile}
    return 1
  fi

  echo ${pid} > "${app_pidfile}"
  echo ${pid}
  return 0
}


#
# get status of a component
#
# @param $1 display detailed information
#
componentStatus() {
  local pid=-1

  if ! pid=$(getPidForComponent) ; then
    return 1
  fi
  local memrss=$(($(ps -o "rss" ${pid} | grep -v RSS)/1024))
  local threads=$(ps -elL | grep ${pid} | wc -l)
  echo "PID(${pid}),THR(${threads}),MEM(${memrss}M)"
  return 0
}


#
# start a component
#
componentStart() {
  local pid=-1

  if ! pid=$(getPidForComponent) ; then
    # generate start command
    #JVM_OPTIONS="${JVM_OPTIONS} -XX:OnOutOfMemoryError='kill -9 %p'"
    if [ -e "${app_logcfg}" ] ; then
      JVM_OPTIONS="${JVM_OPTIONS} -Dlogback.configurationFile=file:${app_logcfg}"
    fi
    if [ "${JMX_ENABLED}" == "true" ] && [ ! -z "${JVM_JMXPORT}" ] && [ -f "${app_jmxpwd}" ] && [ -f "${app_jmxacl}" ] ; then
      JVM_OPTIONS="${JVM_OPTIONS}\
        -Dcom.sun.management.jmxremote.ssl=false\
        -Dcom.sun.management.jmxremote.port=${JVM_JMXPORT}\
        -Dcom.sun.management.jmxremote.password.file=${app_jmxpwd}\
        -Dcom.sun.management.jmxremote.access.file=${app_jmxacl}"
    fi
    local cmd_start=$(echo "${cmd_java} ${JVM_OPTIONS} -jar ${app_jarfile} -c ${app_cfgfile}" | sed "s/[[:blank:]][[:blank:]]*/ /g")

    # prepare for start
    if [ -s ${app_logfile} ] ; then
      local oldLogfile="${app_logfile}.$(date +%F_%T)"
      mv ${app_logfile} ${oldLogfile}
    fi
    echo -e "\n${rundate}\t${cmd_start}" >${app_logfile}

    # actually start component
    ${cmd_start} >/dev/null 2>>${app_logfile} &

    # wait until timeout or running component
    local waitfor=0
    while [ ${waitfor} -lt ${initwait} ] && ! pid=$(getPidForComponent true) ; do
      sleep 1
      ((waitfor++))
    done
  fi
  return $?
}


#
# stop a component
#
componentStop() {
  local force=${1:-false}
  local rc=0
  local pid=-1

  if pid=$(getPidForComponent) ; then
    kill -s TERM ${pid} >/dev/null 2>&1
    if [ "${force}" != "true" ] ; then
      local waitfor=0
      while [ ${waitfor} -lt ${killwait} ] && checkpid ${pid} ; do
        sleep 1
        ((waitfor++))
      done
    fi

    if checkpid ${pid} ; then
      if kill -s KILL ${pid} >/dev/null 2>&1 ; then
        echo -e "\n${rundate}\tKILLED!" >>${app_logfile}
        echo "KILLED"
        rm -f ${app_pidfile}
      else
        echo -e "\n${rundate}\tstop failed!" >>${app_logfile}
        rc=1
      fi
    else
      rm -f ${app_pidfile}
    fi
  fi
  return ${rc}
}


# main program
case "${action}" in
  start)
    # start component
    echo -n ${app_name}
    output=$(componentStart)
    rc=$?
    echo -en "\\033[30G\\033[1;33m${output}\\033[0;39m"
    if [ ${rc} -eq 0 ] ; then
      success
    else
      failure
    fi
    echo
    ;;
  stop)
    # stop component
    echo -n ${app_name}
    output=$(componentStop)
    rc=$?
    echo -en "\\033[30G\\033[1;33m${output}\\033[0;39m"
    if [ ${rc} -eq 0 ] ; then
      success
    else
      failure
    fi
    echo
    ;;
  kill)
    # kill component
    echo -n ${app_name}
    output=$(componentStop true)
    rc=$?
    echo -en "\\033[30G\\033[1;33m${output}\\033[0;39m"
    if [ ${rc} -eq 0 ] ; then
      success
    else
      failure
    fi
    echo
    ;;
  detail|status)
    # show status
    echo -n ${app_name}
    output=$(componentStatus)
    rc=$?
    echo -en "\\033[30G\\033[1;33m${output}\\033[0;39m"
    if [ ${rc} -eq 0 ] ; then
      success
    else
      failure
    fi
    echo
    ;;
  restart)
    # restart component
    if componentStatus ; then
      $0 stop
      sleep 2
    fi
    $0 start
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status|kill|validate} [<componentname>|all]"
    exit 255
    ;;
esac

exit ${rc}
