define activecheck::collector::graphite (
  $host = $name,
  $port = 2003,
  $prefix = 'activecheck',
  $interval_in_seconds = 10,
  $version = $activecheck::params::collector_graphite_version,
  $ensure = present
) {
  # validate parameters
  validate_string($host, $prefix)
  validate_ip_port($port)
  validate_integer($interval_in_seconds)
  validate_re($version, '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$')
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $plugin_class = 'org.activecheck.plugin.collector.graphite.GraphiteCollector'

  # configure shorewall if needed
  @shorewall::rule {
    "activecheckCollector_fw2graphite_${name}" :
      ensure => $ensure,
      action => 'ACCEPT',
      src => 'fw',
      dst => shorewall_zonehost('all', $host),
      dst_port => $port,
      proto => 'tcp' ;
  }

  # create configuration
  activecheck::plugin {
    $name :
      ensure => $ensure,
      version => $version,
      plugin_name => 'activecheck-collector-graphite',
      plugin_config => template('activecheck/collector/graphite.conf.erb') ;
  }
}
