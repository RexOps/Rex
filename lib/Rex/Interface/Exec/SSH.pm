#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::SSH;

use strict;
use warnings;

use Rex::Helper::SSH2;
use File::Basename 'basename';
use Rex::Interface::Shell;
require Rex::Commands;

# Use 'parent' is recommended, but from Perl 5.10.1 its in core
use base 'Rex::Interface::Exec::Base';

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub direct_exec {
  my ( $self, $exec, $option ) = @_;

  Rex::Commands::profiler()->start("direct_exec: $exec");

  Rex::Logger::debug("SSH/executing: $exec");
  my ( $out, $err ) = $self->_exec( $exec, $option );

  Rex::Commands::profiler()->end("direct_exec: $exec");

  Rex::Logger::debug($out) if ($out);
  if ($err) {
    Rex::Logger::debug("========= ERR ============");
    Rex::Logger::debug($err);
    Rex::Logger::debug("========= ERR ============");
  }

  if (wantarray) { return ( $out, $err ); }

  return $out;
}

sub exec {
  my ( $self, $cmd, $path, $option ) = @_;

  Rex::Logger::debug("Executing: $cmd");

  Rex::Commands::profiler()->start("exec: $cmd");

  my $used_shell = $self->_get_shell();

  my $shell;

  if ( $option->{_force_sh} ) {
    $shell = Rex::Interface::Shell->create("Sh");
  }
  else {
    $shell = Rex::Interface::Shell->create($used_shell);
  }

  $shell->set_locale("C");
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

  my $exec = $shell->exec( $cmd, $option );
  Rex::Logger::debug("SSH/executing: $exec");
  my ( $out, $err ) = $self->_exec( $exec, $option );

  Rex::Commands::profiler()->end("exec: $cmd");

  Rex::Logger::debug($out) if ($out);
  if ($err) {
    Rex::Logger::debug("========= ERR ============");
    Rex::Logger::debug($err);
    Rex::Logger::debug("========= ERR ============");
  }

  if (wantarray) { return ( $out, $err ); }

  return $out;
}

sub _exec {
  my ( $self, $exec, $option ) = @_;

 # my $callback = $option->{continuous_read} || undef;
 # $option->{continuous_read} ||= $callback;
  
  my $ssh = Rex::is_ssh();
  my ( $out, $err ) = net_ssh2_exec( $ssh, $exec, $self, $option );

  return ( $out, $err );
}

sub _get_shell {
  my ($self) = @_;

  my ($shell_path) = $self->_exec("echo \$SHELL");
  $shell_path ||= '/bin/sh';    # fallback to /bin/sh
  chomp $shell_path;

  my $used_shell = basename($shell_path);
  return $used_shell;
}

1;
