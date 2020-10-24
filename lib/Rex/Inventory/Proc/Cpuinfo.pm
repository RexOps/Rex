#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Proc::Cpuinfo;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Commands::File;
use Rex::Commands::Fs;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub get {
  my ($self) = @_;

  my @ret;

  if ( is_readable('/proc/cpuinfo') ) {

    my @cpuinfo = split /\n/, cat "/proc/cpuinfo";
    chomp @cpuinfo;

    my $proc = 0;
    for my $line (@cpuinfo) {
      next if $line =~ qr{^$};
      my ( $key, $val ) = split /\s*:\s*/, $line, 2;
      if ( $key eq "processor" ) {
        $proc = $val;
        $ret[$proc] = {};
        next;
      }

      $ret[$proc]->{$key} = $val;
    }
  }
  else {
    Rex::Logger::info( 'Cannot read /proc/cpuinfo', 'warn' );
  }

  return \@ret;
}

1;
