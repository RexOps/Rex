#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::Run;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Net::OpenSSH::ShellQuoter;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Helper::Path;
use Carp;
require Rex::Commands;
require Rex::Config;

@EXPORT = qw(upload_and_run i_run i_exec i_exec_nohup);

sub upload_and_run {
  my ( $template, %option ) = @_;

  my $rnd_file = get_tmp_file;

  my $fh = Rex::Interface::File->create;
  $fh->open( ">", $rnd_file );
  $fh->write($template);
  $fh->close;

  my $fs = Rex::Interface::Fs->create;
  $fs->chmod( 755, $rnd_file );

  my @argv;
  my $command = $rnd_file;

  if ( exists $option{with} ) {
    $command = Rex::Config->get_executor_for( $option{with} ) . " $command";
  }

  if ( exists $option{args} ) {
    $command .= join( " ", @{ $option{args} } );
  }

  return i_run("$command 2>&1");
}

# internal run command, doesn't get reported
sub i_run {
  my $cmd = shift;
  my ( $code, $option );
  $option = {};
  if ( ref $_[0] eq "CODE" ) {
    $code = shift;
  }
  if ( scalar @_ > 0 ) {
    $option = {@_};
  }

  $option->{valid_retval} ||= [0];
  $option->{fail_ok} //= 0;

  if ( $option->{no_stderr} ) {
    $cmd = "$cmd 2>/dev/null";
  }

  if ( $option->{stderr_to_stdout} ) {
    $cmd = "$cmd 2>&1";
  }

  if ( ref $option->{valid_retval} ne "ARRAY" ) {
    $option->{valid_retval} = [ $option->{valid_retval} ];
  }

  my $is_no_hup       = 0;
  my $tmp_output_file = get_tmp_file();
  if ( exists $option->{nohup} && $option->{nohup} ) {
    $cmd = "nohup $cmd >$tmp_output_file";
    delete $option->{nohup};
    $is_no_hup = 1;
  }

  my $path;

  if ( !Rex::Config->get_no_path_cleanup() ) {
    $path = join( ":", Rex::Config->get_path() );
  }

  my $exec = Rex::Interface::Exec->create;
  my ( $out, $err ) = $exec->exec( $cmd, $path, $option );
  my $ret_val = $?;

  chomp $out if $out;
  chomp $err if $err;

  $Rex::Commands::Run::LAST_OUTPUT = [ $out, $err ];

  $out ||= "";
  $err ||= "";

  if ( scalar( grep { $_ == $ret_val } @{ $option->{valid_retval} } ) == 0 ) {
    if ( !$option->{fail_ok} ) {
      Rex::Logger::debug("Error executing `$cmd`: ");
      Rex::Logger::debug("STDOUT:");
      Rex::Logger::debug($out);
      Rex::Logger::debug("STDERR:");
      Rex::Logger::debug($err);

      if ($is_no_hup) {
        $out = $exec->exec("cat $tmp_output_file ; rm -f $tmp_output_file");
        $Rex::Commands::Run::LAST_OUTPUT = [$out];
        $?                               = $ret_val;
      }

      confess("Error during `i_run`");
    }
  }

  if ($code) {
    return &$code( $out, $err );
  }

  if (wantarray) {
    return split( /\r?\n/, $out );
  }

  if ($is_no_hup) {
    $out = $exec->exec("cat $tmp_output_file ; rm -f $tmp_output_file");
    $Rex::Commands::Run::LAST_OUTPUT = [$out];
    $?                               = $ret_val;
  }

  return $out;
}

sub i_exec {
  my ( $cmd, @args ) = @_;

  my $exec   = Rex::Interface::Exec->create;
  my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );

  my $_cmd_str = "$cmd " . join( " ", map { $quoter->quote($_) } @args );

  i_run $_cmd_str;
}

sub i_exec_nohup {
  my ( $cmd, @args ) = @_;

  my $exec   = Rex::Interface::Exec->create;
  my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );

  my $_cmd_str = "$cmd " . join( " ", map { $quoter->quote($_) } @args );
  i_run $_cmd_str, nohup => 1;
}

1;
