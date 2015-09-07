define activecheck::service::graylog (
  $service_description = $name,
  $service_host = undef,
  $url,
  $api_username = undef,
  $api_password = undef,
  $check_interval_in_seconds = 60,
  $retry_interval_in_seconds = 60,
  $first_notification_delay_in_minutes = 0,
  $max_check_attempts = undef,
  $max_errors = 0,
  $template = undef,
  $escalation_type = undef,
  $notifications_enabled = undef,
  $only_on_collector = undef,
  $dependent_service_description = undef,
  $report_results = undef,
  $graph_results = undef,
  $graph_perfdata = undef,
  $fixit = {},
  $version = $activecheck::params::reporter_graylog_version,
  $ensure = present
) {
  # validate parameters
  validate_string(
    $service_description, $api_username, $api_password,
    $url, $dependent_service_description, $service_host,
  )
  validate_integer(
    $check_interval_in_seconds, $retry_interval_in_seconds, $max_errors,
    $first_notification_delay_in_minutes,
  )
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
  $plugin_class = 'org.activecheck.plugin.reporter.graylog.GraylogReporter'

  # create configuration
  activecheck::plugin {
    $name :
      ensure => $ensure,
      version => $version,
      plugin_name => 'activecheck-reporter-graylog',
      plugin_config => template('activecheck/service/graylog.conf.erb') ;
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
