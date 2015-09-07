class activecheck::params (
  $version = '1.0.0',
  $reporter_graylog_version = '1.0.0',
  $reporter_jmx_version = '1.0.0',
  $reporter_nrpe_version = '1.0.0',
  $reporter_mongodb_version = '1.0.0',
  $collector_graphite_version = '1.0.0',
  $collector_nsca_version = '1.0.0',
  $collector_nagmq_version = '1.0.0',
) {
  # define variables
  $service_name = 'activecheck'
  $freshness_boundary_in_seconds = 30
  $freshness_boundary_quotient = 1.5
  $activecheck_error_delay_in_seconds = 120

  # files and directories
  $cfgdir = '/etc/activecheck'
  $cfgddir = "${cfgdir}/conf.d"
  $rundir = '/usr/share/activecheck'
  $plugindir = "${rundir}/plugins"

  $cfgfile = "${cfgdir}/${service_name}.cfg"
  $sysconfig = "/etc/sysconfig/${service_name}"
  $logbackcfg = "${cfgdir}/logback.xml"
  $jarfile = "${rundir}/activecheck.jar"
  $pidfile = "/var/run/${service_name}.pid"
  $rcscript = "/etc/init.d/${service_name}"
  $jmxpwdfile = "${cfgdir}/jmxremote.password"
  $jmxaclfile = "${cfgdir}/jmxremote.access"
}
