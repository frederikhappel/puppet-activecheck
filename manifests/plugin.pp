define activecheck::plugin (
  $version,
  $plugin_name,
  $plugin_config,
  $enabled = true,
  $ensure = $activecheck::ensure
) {
  # validate parameters
  validate_re($version, '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$')
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }
  validate_string($plugin_name, $plugin_config)
  validate_bool($enabled)
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $cfgfile = "${activecheck::params::cfgddir}/${name}.conf"
  $pluginjar = "${activecheck::params::plugindir}/${plugin_name}.jar"

  # configure component
  case $ensure {
    present: {
      # create component configuration
      file {
        $cfgfile :
          content => $plugin_config,
          owner => 0,
          group => 0,
          mode => '0600' ;
      }
      if $enabled and !defined(File[$pluginjar]) {
        file {
          $pluginjar: # TODO: change to packages
            source => "puppet:///modules/activecheck/plugins/${plugin_name}-${version}.jar",
            owner => 0,
            group => 0,
            mode => '0644' ;
        }
      }
    }

    absent: {
      # delete component configuration
      file {
        $cfgfile :
          ensure => absent,
          force => true,
          recurse => true,
          backup => false ;
      }
    }
  }
}
