class activecheck (
  $runstyle = 'off',
  $worker = 1,
  $reload_interval_in_seconds = 60,
  $hostcheck_interval_in_seconds = 10,
  $servicecheck_interval_in_seconds = 10,
  $monitorjar = true,
  $jmx_username = undef,
  $jmx_password = undef,
  $jmx_remote = {},
  $jmx_port = 9999,
  $jmx_allow_from = [],
  $nsca_proxy = false,
  $nrpe_host = '127.0.0.1',
  $nrpe_port = 5666,
  $nrpe_timeout_in_seconds = 30,
  $xmx_in_mb = 32,
  $xms_in_mb = 32,
  $logger = 'WARN',
  $loghost = undef,
  $loghost_port = 12201,
  $logtofile = true,
  $report_results = true, # submit check results to reporting tools (nagios)
  $graph_results = false, # submit check results to graphing tools (graphite)
  $graph_perfdata = true, # submit performance data to graphing tools (graphite)
  $ensure = present
) inherits activecheck::params {
  # validate parameters
  validate_re($runstyle, '^(service|daemon|monit|off)$')
  validate_integer(
    $worker, $servicecheck_interval_in_seconds, $reload_interval_in_seconds,
    $hostcheck_interval_in_seconds, $nrpe_timeout_in_seconds, $xmx_in_mb,
    $xms_in_mb,
  )
  validate_bool(
    $monitorjar, $nsca_proxy, $report_results, $graph_results,
    $graph_perfdata, $logtofile,
  )
  validate_array($jmx_allow_from)
  validate_hash($jmx_remote)
  validate_string(
    $jmx_username, $jmx_password, $nrpe_host, $loghost,
  )
  validate_ip_port($jmx_port, $nrpe_port, $loghost_port)
  validate_re($version, '^([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*)$')
  validate_re($logger, '^(TRACE|DEBUG|INFO|WARN|ERROR)$')
  validate_re($ensure, '^(present|absent)$')

  # clean up activecheck logs
  cron {
    'activecheck_logrotate':
      ensure => $ensure,
      command => "find /var/log/activecheck* -mtime +3 -delete >/dev/null 2>&1",
      user => 'root',
      hour => 0,
      minute => 2;
  }

  # configure shorewall if needed
  $ensure_jmx = empty($jmx_remote) ? { true => absent, default => $ensure }
  Shorewall::Rule {
    action => 'ACCEPT',
    src => 'fw',
    proto => 'tcp',
  }
  @shorewall::rule {
    'activecheck_fw2loghost' :
      ensure => $loghost ? { undef => absent, default => $ensure },
      dst => shorewall_zonehost('all', $loghost),
      dst_port => [$loghost_port] ;

    'activecheck_all2jmx' :
      ensure => $ensure_jmx,
      src => shorewall_zonehost('all', $jmx_allow_from),
      dst => 'fw',
      dst_port => [$jmx_port] ;
  }

  case $ensure {
    present: {
      File {
        owner => 0,
        group => 0,
        mode => '0600',
        backup => false,
      }
      file {
        [$cfgdir, $rundir, $plugindir] :
          ensure => directory,
          force => true,
          mode => '0755' ;

        $cfgddir :
          ensure => directory,
          recurse => true,
          force => true,
          purge => true ;

        $jarfile : # TODO: change to packages
          source => "puppet:///modules/activecheck/activecheck-server-${version}.jar",
          mode => '0644' ;

        $cfgfile :
          content => template('activecheck/activecheck.conf.erb') ;

        $sysconfig :
          content => template('activecheck/sysconfig.erb') ;

        $logbackcfg :
          content => template('activecheck/logback.xml.erb') ;

        $rcscript :
          source => 'puppet:///modules/activecheck/activecheck.sh',
          mode => '0755' ;

        $jmxpwdfile :
          ensure => $ensure_jmx,
          content => template('activecheck/jmx_password.erb') ;

        $jmxaclfile :
          ensure => $ensure_jmx,
          content => template('activecheck/jmx_access.erb') ;
      }

      # determine start type
      case $runstyle {
        /(service|daemon|monit)/ : {
          # run as system service
          service {
            $service_name :
              ensure => running,
              enable => true,
              hasrestart => true,
              hasstatus => true,
              subscribe => File[
                $jmxpwdfile, $jmxaclfile, $jarfile, $cfgfile,
                $rcscript, $sysconfig
              ],
              require => File[$cfgddir, $logbackcfg] ;
          }

          # supervise with monit?
          monit::check::process {
            $service_name :
              ensure => $runstyle ? { 'monit' => present, default => absent },
              manageinitd => false,
              pidfile => $pidfile,
              start_program => "/sbin/service ${service_name} start",
              start_timeout_in_seconds => 5,
              stop_program => "/sbin/service ${service_name} stop",
              conditions => [
                'if uptime > 168 hours then restart',
                'if totalcpu > 30% for 5 cycles then restart',
              ],
              require => Service[$service_name] ;
          }
        }

        /off/ : { # disable service
          service {
            $service_name :
              enable => false,
              hasrestart => true,
              hasstatus => true,
              require => File[
                $cfgddir, $jarfile, $cfgfile,
                $rcscript, $logbackcfg, $sysconfig
              ] ;
          }
        }
      }

      # realize all defined services
      Activecheck::Service::Jmx <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
      Activecheck::Service::Nrpe <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
      Activecheck::Service::Graylog <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
      Activecheck::Service::Mongodb <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }

      # realize all defined collectors
      Activecheck::Collector::Nagmq <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
      Activecheck::Collector::Nsca <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
      Activecheck::Collector::Graphite <||> {
        before => File[$rcscript],
        require => File[$cfgddir],
      }
    }

    absent: {
      # delete config file
      file {
        [$cfgdir, $jarfile, $rcscript, $sysconfig] :
          ensure  => absent,
          recurse => true,
          force   => true;
      }
    }
  }
}
