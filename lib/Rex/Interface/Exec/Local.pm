#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::Local;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands;

use Symbol 'gensym';
use IPC::Open3;
use IO::Select;
use Rex::Interface::Exec::IOReader;

# Use 'parent' is recommended, but from Perl 5.10.1 its in core
use base qw(Rex::Interface::Exec::Base Rex::Interface::Exec::IOReader);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub set_env {
  my ( $self, $env ) = @_;
  my $cmd = undef;

  die("Error: env must be a hash")
    if ( ref $env ne "HASH" );

  while ( my ( $k, $v ) = each(%$env) ) {
    $cmd .= "export $k='$v'; ";
  }
  $self->{env} = $cmd;
}

sub exec {
  my ( $self, $cmd, $path, $option ) = @_;

  my ( $out, $err, $pid );

  if ( exists $option->{cwd} ) {
    $cmd = "cd " . $option->{cwd} . " && $cmd";
  }

  if ( exists $option->{path} ) {
    $path = $option->{path};
  }

  if ( exists $option->{env} ) {
    $self->set_env( $option->{env} );
  }

  if ( exists $option->{format_cmd} ) {
    $option->{format_cmd} =~ s/\{\{CMD\}\}/$cmd/;
    $cmd = $option->{format_cmd};
  }

  Rex::Commands::profiler()->start("exec: $cmd");
  if ( $^O !~ m/^MSWin/ ) {
    if ($path) { $path = "PATH=$path" }
    $path ||= "";

    my $new_cmd = "LC_ALL=C $cmd";
    if ($path) {
      $new_cmd = "export $path ; $new_cmd";
    }

    if ( $self->{env} ) {
      $new_cmd = $self->{env} . " $new_cmd";
    }

    if ( Rex::Config->get_source_global_profile ) {
      $new_cmd = ". /etc/profile >/dev/null 2>&1; $new_cmd";
    }

    $cmd = $new_cmd;
  }

  Rex::Logger::debug("Executing: $cmd");

  ( $out, $err ) = $self->_exec( $cmd, $option );

  Rex::Logger::debug($out) if ($out);
  if ($err) {
    Rex::Logger::debug("========= ERR ============");
    Rex::Logger::debug($err);
    Rex::Logger::debug("========= ERR ============");
  }

  Rex::Commands::profiler()->end("exec: $cmd");

  if (wantarray) { return ( $out, $err ); }

  return $out;
}

sub can_run {
  my ( $self, $commands_to_check, $check_with_command ) = @_;

  $check_with_command ||= $^O =~ /^MSWin/i ? 'where' : 'which';

  return $self->SUPER::can_run( $commands_to_check, $check_with_command );
}

sub _exec {
  my ( $self, $cmd, $option ) = @_;

  my ( $pid, $writer, $reader, $error, $out, $err );
  $error = gensym;

  if ( $^O !~ m/^MSWin/ && Rex::Config->get_no_tty ) {
    $pid = open3( $writer, $reader, $error, $cmd );

    ( $out, $err ) = $self->io_read( $reader, $error, $pid, $option );

    waitpid( $pid, 0 ) or die($!);
  }
  else {
    $pid = open( my $fh, "-|", "$cmd 2>&1" ) or die($!);
    while (<$fh>) {
      $out .= $_;
      chomp;
      $self->execute_line_based_operation( $_, $option )
        && do { kill( 'KILL', $pid ); last };
    }
    waitpid( $pid, 0 ) or die($!);

  }

  # we need to bitshift $? so that $? contains the right (and for all
  # connection methods the same) exit code after a run()/i_run() call.
  # this is for the user, so that he can query $? in his task.
  $? >>= 8;

  return ( $out, $err );
}

1;
