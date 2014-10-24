#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::Run;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Helper::Path;
require Rex::Commands;
require Rex::Config;

@EXPORT = qw(upload_and_run i_run);

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
  if ( ref $_[0] eq "CODE" ) {
    $code = shift;
  }
  elsif ( scalar @_ > 0 ) {
    $option = {@_};
  }

  my $is_no_hup       = 0;
  my $tmp_output_file = get_tmp_file();
  if ( exists $option->{nohup} && $option->{nohup} ) {
    $cmd = "nohup $cmd >$tmp_output_file";
    delete $option->{nohup};
    $is_no_hup = 1;
  }

  my $path = join( ":", Rex::Config->get_path() );

  my $exec = Rex::Interface::Exec->create;
  my ( $out, $err ) = $exec->exec( $cmd, $path, $option );
  chomp $out if $out;
  chomp $err if $err;

  my $ret_val = $?;

  $Rex::Commands::Run::LAST_OUTPUT = [ $out, $err ];

  $out ||= "";
  $err ||= "";

  if ($code) {
    return &$code( $out, $err );
  }

  if (wantarray) {
    return split( /\r?\n/, $out );
  }

  if ($is_no_hup) {
    $out = $exec->exec("cat $tmp_output_file ; rm -f $tmp_output_file");
  }

  return $out;
}

1;
