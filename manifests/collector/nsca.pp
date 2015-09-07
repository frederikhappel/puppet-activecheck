define activecheck::collector::nsca (
  $host = $name,
  $port = 5667,
  $version = $activecheck::params::collector_nsca_version,
  $ensure = present
) {
  # validate parameters
  validate_string($host)
  validate_ip_port($port)
  validate_re($version, '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$')
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $plugin_class = 'org.activecheck.plugin.collector.nsca.NscaCollector'

  # configure shorewall if needed
  @shorewall::rule {
    "activecheckCollector_fw2nsca_${name}" :
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
      plugin_name => 'activecheck-collector-nsca',
      plugin_config => template('activecheck/collector/nsca.conf.erb') ;
  }
}
