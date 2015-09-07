define activecheck::collector::nagmq (
  $host = $name,
  $port = 5556,
  $hwm = 1000,
  $version = $activecheck::params::collector_nagmq_version,
  $ensure = present
) {
  # validate parameters
  validate_string($host)
  validate_ip_port($port)
  validate_integer($hwm)
  validate_re($version, '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$')
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $plugin_class = 'org.activecheck.plugin.collector.nagmq.NagmqCollector'

  # configure shorewall if needed
  @shorewall::rule {
    "activecheckCollector_fw2nagmq_${name}" :
      ensure => $ensure,
      action => 'ACCEPT',
      src => 'fw',
      dst => shorewall_zonehost('all', $host),
      dst_port => [$port, 5557],
      proto => 'tcp' ;
  }

  # create configuration
  activecheck::plugin {
    $name :
      ensure => $ensure,
      version => $version,
      plugin_name => 'activecheck-collector-nagmq',
      plugin_config => template('activecheck/collector/nagmq.conf.erb') ;
  }
}
