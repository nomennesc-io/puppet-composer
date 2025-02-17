#   Copyright 2013 Brainsware
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# = Defined Type composer::project
#
#  This defined type helps install a project with composer and keep it up-todate
#
# == Parameters:
#
# [*ensure*]
#   Can be either 'present' or 'latest'. 'installed' is a synonym for 'present'. Default: present
#
# [*source*]
#   Package name to create project from, may optionally contain a version, e.g. 'monolog/monolog:~1.0'. Default: undef
#
# [*target*]
#   Where to install this composer project. Must exist! Defaults to $title
#
# [*dev*]
#   Toggle the installation of require-dev packages. Default: false
#
# [*scripts*]
#   Toggles the execution of all scripts defined in composer.json. Default: true
#
# [*custom_inst*]
#   Toggles the execution of all custom installers. Default: true
#
# [*prefer*]
#   Define a preference for either 'source' or 'dist' (package) distribution. Default: 'dist'
#
# [*lock*]
#   Toggles whether to update only the hash in composer.lock to avoid "out of date" warnings. Default: false
#
# [*user*]
#   The owner of the project. Default: 'root'
#
# [*php_bin*]
#   Specify a PHP binary to run composer with. Defaults to system default.
#

define composer::project (
  Enum['present','installed','latest'] $ensure      = present,
  Enum['dist','source']                $prefer      = 'dist',
  Boolean                              $dev         = false,
  Boolean                              $scripts     = true,
  Boolean                              $custom_inst = true,
  $source                                           = undef,
  $target                                           = $title,
  $lock                                             = false,
  $user                                             = 'root',
  $php_bin                                          = '',
) {
  include composer

  $composer  = strip("${php_bin} ${composer::target_dir}/${composer::command_name}")
  $base_opts = '--no-interaction --quiet --no-progress'

  $dev_opt = $dev? {
    true  => '--dev',
    false => '--no-dev',
  }
  $script_opt = $scripts? {
    true  => [],
    false => '--no-scripts',
  }
  $custom_inst_opt = $custom_inst? {
    true  => [],
    false => '--no-custom-installer',
  }
  $lock_opt = $lock? {
    false => [],
    true  => '--lock',
  }

  $create_project_opts = join(flatten([$dev_opt, "--prefer-${prefer}", '--keep-vcs']), ' ')
  $install_opts = join(flatten([$dev_opt, $script_opt, $custom_inst_opt, "--prefer-${prefer}" ]), ' ')
  $update_opts = join(flatten([$dev_opt, $script_opt, $custom_inst_opt, "--prefer-${prefer}", $lock_opt ]), ' ')
  $user_home = $user ? {
    'root'  => ['HOME=/root'],
    default => ["HOME=/home/${user}"],
  }

  if $composer::home {
    $composer_home = ["COMPOSER_HOME=${composer::home}"]
  } else {
    $composer_home = []
  }

  $environment = concat(
    $user_home,
    $composer_home
  )

  Exec {
    cwd         => $target,
    path        => $::path,
    provider    => 'posix',
    user        => $user,
    environment => $environment,
    require     => Class['composer'],
  }

  if $source {
    exec { "composer_create_project_${title}":
      command => "${composer} create-project ${base_opts} ${create_project_opts} ${source} .",
      creates => "${target}/composer.json",
      before  => Exec["composer_install_${title}"],
    }
  }

  exec { "composer_install_${title}":
    command => "${composer} install ${base_opts} ${install_opts}",
    onlyif  => "${composer} install ${install_opts} --dry-run 2>&1 | grep -E -- '- (Install|Updat)ing '",
  }

  if $ensure == latest {
    exec { "composer_update_${title}":
      command => "${composer} update ${base_opts} ${update_opts}",
      onlyif  => "${composer} update ${update_opts} --dry-run 2>&1 | grep -E -- '- (Install|Updat)ing '",
    }
  }
}
