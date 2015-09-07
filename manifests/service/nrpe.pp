define activecheck::service::nrpe (
  $service_description = $name,
  $service_host = undef,
  $check_command, # must not contain arguments!
  $check_arguments = [],
  $check_interval_in_seconds = 60,
  $check_timeout_in_seconds = undef,
  $retry_interval_in_seconds = 0,
  $first_notification_delay_in_minutes = 0,
  $max_check_attempts = undef,
  $max_errors = 0,
  $event_handler = undef,
  $template = undef,
  $escalation_type = undef,
  $notifications_enabled = undef,
  $only_on_collector = undef,
  $dependent_service_description = 'nrpe_process',
  $report_results = undef,
  $graph_results = undef,
  $graph_perfdata = undef,
  $fixit = {},
  $version = $activecheck::params::reporter_nrpe_version,
  $ensure = present
) {
  # validate parameters
  validate_string(
    $service_description, $check_command, $dependent_service_description,
    $service_host,
  )
  validate_array($check_arguments)
  validate_integer(
    $check_interval_in_seconds, $retry_interval_in_seconds, $max_errors,
    $first_notification_delay_in_minutes,
  )
  if $check_timeout_in_seconds != undef {
    validate_integer($check_timeout_in_seconds)
  }
  if $max_check_attempts != undef {
    validate_integer($max_check_attempts)
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
  $plugin_class = 'org.activecheck.plugin.reporter.nrpe.NrpeReporter'
  if empty($check_arguments) {
    $nrpe_command = 'puppet_check_nrpe_noargs'
    $check_command_real = join([$nrpe_command, $check_command], '!')
  } else {
    $nrpe_command = 'puppet_check_nrpe'
    $check_command_real = join([$nrpe_command, $check_command, join($check_arguments, ' ')], '!')
  }

  # create configuration
  activecheck::plugin {
    $name :
      ensure => $ensure,
      version => $version,
      plugin_name => 'activecheck-reporter-nrpe',
      plugin_config => template('activecheck/service/nrpe.conf.erb') ;
  }
  @nagioscollector::resource::service {
    $name :
      ensure => $report_results ? { false => absent, default => $ensure },
      service_description => $service_description,
      dependent_service_description => $dependent_service_description,
      passive => true,
      active => false,
      freshness_threshold_in_seconds => sprintf('%i',
        $check_interval_in_seconds * $activecheck::params::freshness_boundary_quotient +
        $activecheck::params::freshness_boundary_in_seconds / $activecheck::params::freshness_boundary_quotient
      ),
      max_check_attempts => $max_check_attempts,
      check_interval_in_min => sprintf('%i', $check_interval_in_seconds / 60),
      first_notification_delay_in_min => $first_notification_delay_in_minutes,
      check_command => $check_command_real,
      event_handler => $event_handler,
      template_override => $template,
      escalation_type_override => $escalation_type,
      notifications_enabled => $notifications_enabled,
      only_on_collector => $only_on_collector ;
  }
}
