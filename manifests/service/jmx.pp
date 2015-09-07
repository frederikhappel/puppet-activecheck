define activecheck::service::jmx (
  $service_description = $name,
  $service_host = undef,
  $query = undef,
  $query_arguments = [],
  $is_operation = false,
  $pidfile = undef,
  $jmx_host = undef,
  $jmx_port = undef,
  $jmx_username = undef,
  $jmx_password = undef,
  $check_interval_in_seconds = 10,
  $retry_interval_in_seconds = 10,
  $first_notification_delay_in_minutes = 0,
  $max_check_attempts = undef,
  $max_errors = 3, # 3 * 120 seconds = 6 mins
  $template = undef,
  $escalation_type = undef,
  $notifications_enabled = undef,
  $only_on_collector = undef,
  $dependent_service_description = undef,
  $report_results = undef,
  $graph_results = undef,
  $graph_perfdata = undef,
  $fixit = {},
  $version = $activecheck::params::reporter_jmx_version,
  $ensure = present
) {
  # validate parameters
  validate_string(
    $service_description, $jmx_host, $jmx_username, $jmx_password,
    $query, $dependent_service_description, $service_host,
  )
  validate_integer(
    $check_interval_in_seconds, $retry_interval_in_seconds, $max_errors,
    $first_notification_delay_in_minutes,
  )
  validate_bool($is_operation)
  validate_array($query_arguments)
  if $max_check_attempts != undef {
    validate_integer($max_check_attempts)
  }
  if ($pidfile != undef) {
    validate_absolute_path($pidfile)
  } elsif ($jmx_port != undef) {
    validate_ip_port($jmx_port)
  } else {
    fail('Either $pidfile or $jmx_port must be specified')
  }
  if $report_results != undef {
    validate_bool($report_results)
  }
  if $graph_results != undef {
    validate_bool($graph_results)
  }
  if $graph_perfdata != undef {
    validate_bool($graph_perfdata)
  }
  validate_hash($fixit)
  validate_re($version, '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$')
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $plugin_class = 'org.activecheck.plugin.reporter.jmx.JMXReporter'

  # create configuration
  activecheck::plugin {
    $name :
      ensure => $ensure,
      version => $version,
      plugin_name => 'activecheck-reporter-jmx',
      plugin_config => template('activecheck/service/jmx.conf.erb') ;
  }
  @nagioscollector::resource::service {
    $name :
      ensure => $report_results ? { false => absent, default => $ensure },
      service_description => $service_description,
      dependent_service_description => $dependent_service_description,
      passive => true,
      active => false,
      freshness_threshold_in_seconds => sprintf('%i',
        $check_interval_in_seconds + $activecheck::params::activecheck_error_delay_in_seconds
      ),
      max_check_attempts => $max_check_attempts,
      first_notification_delay_in_min => $first_notification_delay_in_minutes,
      check_command => 'puppet_check_dummy',
      template_override => $template,
      escalation_type_override => $escalation_type,
      notifications_enabled => $notifications_enabled,
      only_on_collector => $only_on_collector ;
  }
}
