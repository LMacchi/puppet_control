# Class: profiles::puppet_master
# ===========================
#
# Configuration of puppet master profile: R10K and webhook, hiera
#
# Examples
# --------
# 
# include profiles::puppet_master
#
# Authors
# -------
#
# LMacchi <lm@puppetlabs.com>
#
# Copyright
# ---------
#
# Copyright 2015 LMacchi, unless otherwise noted.
#
class profiles::puppet_master {

  # Hiera lookups
  $vcs_token        = hiera('vcs_api_token'),
  $vcs_project_name = hiera('vcs_project'),
  $vcs_server_url   = hiera('vcs_url'),
  $vcs_provider     = hiera('vcs_provider'),

  # Configure R10K
  include pe_r10k

  # Ensure private key is in the server
  file { '/root/.ssh/id_rsa':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    source => 'puppet:///modules/profiles/root_priv.key',
  }

  # Ensure public key is in the server
  file { '/root/.ssh/id_rsa.pub':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    source => 'puppet:///modules/profiles/root_pub.key',
  }

  # R10K fails if the VCS server is not in known hosts
  sshkey { 'vcs_url':
    ensure => present,
    key    => hiera('vcs_host_key'),
    type   => 'rsa',
  }

  # Configure webhook
  class {'r10k::webhook::config':
    enable_ssl      => false,
    protected       => false,
    use_mcollective => false,
    notify          => Service['webhook'],
  }

  # Implement webhook
  class {'r10k::webhook':
    use_mcollective => false,
    user            => 'root',
    group           => '0',
    require         => Class['r10k::webhook::config'],
  }

  # Add webhook to VCS
  git_webhook { 'web_post_receive_webhook' :
    ensure             => present,
    webhook_url        => "${::fqdn}:8088/payload",
    token              => $vcs_token,
    project_name       => $vcs_project_name,
    server_url         => $vcs_server_url,
    disable_ssl_verify => true,
    provider           => 'github',
  }

  git_deploy_key { 'add_deploy_key_to_puppet_control':
    ensure       => present,
    name         => $::fqdn,
    path         => '/root/.ssh/id_rsa.pub',
    token        => $vcs_token,
    project_name => $vcs_project_name,
    server_url   => $vcs_server_url,
    provider     => $vcs_provider,
  }
}
