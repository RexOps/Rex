#
# (c) Jan Gehring <jan.gehring@gmail.com>
# Adapted for doas support by Rafael Medina <rafael@medina.me>
#

package Rex::Interface::Exec::Doas;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Config;
use Rex::Interface::Exec::Local;
use Rex::Interface::Exec::SSH;
use Rex::Interface::File::Local;
use Rex::Interface::File::SSH;

use Rex::Commands;
use Rex::Helper::Path;

use base 'Rex::Interface::Exec::Base';

my $net_openssh = 'Net::OpenSSH';
my $openssh     = 'OpenSSH';
my $ssh_backend = 'SSH';
my $local       = 'Local';

sub new {
  my ( $that, @args ) = @_;

  my $self  = {@args};
  my $proto = ref $that || $that;

  bless $self, $proto;

  return $self;
}

sub exec { ## no critic (Subroutines::ProhibitBuiltinHomonyms)
  my ( $self, $cmd, $path, $option ) = @_;

  if ( exists $option->{cwd} ) {
    $cmd = 'cd ' . $option->{cwd} . " && $cmd";
  }

  if ( exists $option->{path} ) {
    $path = $option->{path};
  }

  my ( $exec, $file, $shell );
  if ( my $ssh = Rex::is_ssh() ) {
    if ( ref $ssh eq $net_openssh ) {
      $exec = Rex::Interface::Exec->create($openssh);
      $file = Rex::Interface::File->create($openssh);
    }
    else {
      $exec = Rex::Interface::Exec->create($ssh_backend);
      $file = Rex::Interface::File->create($ssh_backend);
    }
  }
  else {
    $exec = Rex::Interface::Exec->create($local);
    $file = Rex::Interface::File->create($local);
  }
  $shell = Rex::Interface::Shell->create('Sh');

  my $doas_options =
    Rex::get_current_connection_object()->get_current_doas_options;
  my $doas_options_str = q{};
  if ( exists $doas_options->{user} ) {
    $doas_options_str .= ' -u ' . $doas_options->{user};
  }

  if ( Rex::Config->get_sudo_without_locales() ) {
    Rex::Logger::debug(
      'Using doas without locales. If the locale is NOT C or en_US it will break many things!'
    );
    $option->{no_locales} = 1;
  }

  # doas uses -n for non-interactive (no password prompt)
  my $doas_command = "doas -n $doas_options_str";

  if ( Rex::Config->get_sudo_without_sh() ) {
    Rex::Logger::debug(
      'Using doas without sh will break things like file editing');

    $shell->set_inner_shell(0);
    $shell->set_doas_env(1);

    if ( exists $option->{env} ) {
      $shell->set_environment( $option->{env} );
    }
  }
  else {

    $shell->set_locale('C');
    $shell->path($path);

    if ( Rex::Config->get_source_global_profile ) {
      $shell->source_global_profile(1);
    }

    if ( Rex::Config->get_source_profile ) {
      $shell->source_profile(1);
    }

    if ( exists $option->{env} ) {
      $shell->set_environment( $option->{env} );
    }

    $shell->set_inner_shell(1);
  }

  $option->{prepend_command} = $doas_command;

  my $real_exec = $shell->exec( $cmd, $option );
  Rex::Logger::debug("doas: exec: $real_exec");

  return $exec->direct_exec( $real_exec, $option );
}

sub _exec { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my ( $self, $cmd, $path, $option ) = @_;

  my ( $exec, $file, $shell );
  if ( my $ssh = Rex::is_ssh() ) {
    if ( ref $ssh eq $net_openssh ) {
      $exec = Rex::Interface::Exec->create($openssh);
    }
    else {
      $exec = Rex::Interface::Exec->create($ssh_backend);
    }
  }
  else {
    $exec = Rex::Interface::Exec->create($local);
  }

  return $exec->_exec( $cmd, $option );
}

1;
