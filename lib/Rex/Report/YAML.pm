#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Report::YAML;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex;
use Data::Dumper;
use Rex::Report::Base;
require Rex::Commands;
use YAML;
use base qw(Rex::Report::Base);

our $REPORT_PATH = "./reports";

my $report_name_generator = sub {
  my $str = time();
  return $str;
};

sub set_report_name {
  my ( $class, $code ) = @_;

  if ( ref $class eq "CODE" ) {
    $code = $class;
  }

  if ( ref $code ne "CODE" ) {
    die "Rex::Report::YAML->set_report_name(\$code_ref) wrong arguments.";
  }

  $report_name_generator = $code;
}

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub write_report {
  my ($self) = @_;

  $REPORT_PATH = Rex::Commands::get('report_path') || "reports";

  if ( !-d $REPORT_PATH ) {
    mkdir $REPORT_PATH or die( $! . ": $REPORT_PATH" );
  }

  my $server_name = Rex::Commands::connection()->server;
  if ( $server_name eq "<local>" ) {
    $server_name = "_local_";
  }
  if ( !-d $REPORT_PATH . "/" . $server_name ) {
    mkdir "$REPORT_PATH/$server_name";
  }
  open(
    my $fh,
    ">",
    "$REPORT_PATH/$server_name/"
      . $report_name_generator->($server_name) . ".yml"
  ) or die($!);
  print $fh Dump( $self->{__reports__} );
  close($fh);

  $self->{__reports__} = {};
}

# $self->report({
#     command   => $export,
#     module    => "Rex::Commands::$mod",
#     start_time => $start_time,
#     end_time  => time,
#     data     => [ @_ ],
#     success   => 1,
#     changed   => 1,
#     message   => "",

1;
