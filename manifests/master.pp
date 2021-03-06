# == Class: jenkins::master
#
class jenkins::master(
  $logo = '',
  $vhost_name = $::fqdn,
  $serveradmin = "webmaster@${::fqdn}",
  $ssl_cert_file = '',
  $ssl_key_file = '',
  $ssl_chain_file = '',
  $ssl_cert_file_contents = '', # If left empty puppet will not create file.
  $ssl_key_file_contents = '', # If left empty puppet will not create file.
  $ssl_chain_file_contents = '', # If left empty puppet will not create file.
  $jenkins_ssh_private_key = '',
  $jenkins_ssh_public_key = '',
) {
  include pip
  if ($operatingsystem !~ /Redhat|CentOS/) {
      include apt
  }
#  include apache

  $nogroup = $operatingsystem ? {
        /Redhat|CentOS/  => "nobody",
        default => "nogroup",
  }


  $openjdk7 = $operatingsystem ? {
        /Redhat|CentOS/  => "java-1.7.0-openjdk-headless",
        default => "openjdk-7-jre-headless",
  }
  package { "$openjdk7":
    ensure => present,
    alias => "openjdk-7-jre-headless",
  }

  package { 'openjdk-6-jre-headless':
    ensure  => purged,
    require => Package['openjdk-7-jre-headless'],
  }

  if ($operatingsystem !~ /Redhat|CentOS/) {
      #This key is at http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key
      apt::key { 'jenkins':
        key        => 'D50582E6',
        key_source => 'http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key',
      }

      apt::source { 'jenkins':
        location    => 'http://pkg.jenkins-ci.org/debian-stable',
        release     => 'binary/',
        repos       => '',
        require     => [
          Apt::Key['jenkins'],
          Package['openjdk-7-jre-headless'],
        ],
        include_src => false,
      }
  }
  else {
        exec {'setup_jenkins_repo':
            command => "wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo",
            path => "/usr/bin/",
        }
        exec {'install_jenkins_key':
            command => "rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key",
            path => "/usr/bin/",
        }
  }

#  apache::vhost { $vhost_name:
#    port     => 443,
#    docroot  => '/var/www/html',
#    priority => '50',
#    template => 'jenkins/jenkins.vhost.erb',
#    ssl      => true,
#  }
#  if ! defined(A2mod['proxy_http']) {
#    a2mod { 'proxy_http':
#      ensure => present,
#    }
#  }

  if $ssl_cert_file_contents != '' {
    file { $ssl_cert_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_cert_file_contents,
#      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_key_file_contents != '' {
    file { $ssl_key_file:
      owner   => 'root',
      group   => 'ssl-cert',
      mode    => '0640',
      content => $ssl_key_file_contents,
      require => Package['ssl-cert'],
#      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_chain_file_contents != '' {
    file { $ssl_chain_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_chain_file_contents,
#      before  => Apache::Vhost[$vhost_name],
    }
  }

  $openssl = $operatingsystem ? {
        /Redhat|CentOS/  => "openssl",
        default => "ssl-cert",
  }

  package { $openssl:
    ensure => present,
    alias => 'ssl-cert',
  }

  $packages = [
    'python-babel',
    'python-sqlalchemy',  # devstack-gate
    'sqlite', # interact with devstack-gate DB
  ]

  package { $packages:
    ensure => present,
  }

    if ($operatingsystem !~ /Redhat|CentOS/) {
        package { 'jenkins':
            ensure  => present,
            require => Apt::Source['jenkins'],
        }
    }
    else {

        package { 'jenkins':
            ensure  => present,
        }

    }
   if ($operatingsystem !~ /Redhat|CentOS/) {
        exec { 'update apt cache':
            subscribe   => File['/etc/apt/sources.list.d/jenkins.list'],
            refreshonly => true,
            path        => '/bin:/usr/bin',
            command     => 'apt-get update',
        }
    }

  file { '/var/lib/jenkins':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'adm',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => $nogroup,
    mode    => '0700',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa':
    owner   => 'jenkins',
    group   => $nogroup,
    mode    => '0600',
    content => $jenkins_ssh_private_key,
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa.pub':
    owner   => 'jenkins',
    group   => $nogroup,
    mode    => '0644',
    content => "ssh_rsa ${jenkins_ssh_public_key} jenkins@${::fqdn}",
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/plugins':
    ensure  => directory,
    owner   => 'jenkins',
    group   => $nogroup,
    mode    => '0750',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin':
    ensure  => directory,
    owner   => 'jenkins',
    group   => $nogroup,
    require => File['/var/lib/jenkins/plugins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack.css':
    ensure  => present,
    owner   => 'jenkins',
    group   => $nogroup,
    source  => 'puppet:///modules/jenkins/openstack.css',
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack.js':
    ensure  => present,
    owner   => 'jenkins',
    group   => $nogroup,
    content => template('jenkins/openstack.js.erb'),
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack-page-bkg.jpg':
    ensure  => present,
    owner   => 'jenkins',
    group   => $nogroup,
    source  => 'puppet:///modules/jenkins/openstack-page-bkg.jpg',
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/logger.conf':
    ensure  => present,
    owner   => 'jenkins',
    group   => $nogroup,
    source  => 'puppet:///modules/jenkins/logger.conf',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/title.png':
    ensure  => present,
    owner   => 'jenkins',
    group   => $nogroup,
    source  => "puppet:///modules/jenkins/${logo}",
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/usr/local/jenkins':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
}
