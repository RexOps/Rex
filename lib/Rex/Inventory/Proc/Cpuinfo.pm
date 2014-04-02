#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:


package Rex::Inventory::Proc::Cpuinfo;

use strict;
use warnings;

use Data::Dumper;
use Rex::Commands::File;

sub new {
  my $that = shift;
  my $proto = ref($that) || $that;
  my $self = { @_ };

  bless($self, $proto);

  return $self;
}

sub get {
  my ($self) = @_;

  my @cpuinfo = split /\n/, cat "/proc/cpuinfo";
  chomp @cpuinfo;

  my @ret;
  my $proc = 0;
  for my $line (@cpuinfo) {
    my ($key, $val) = split /\s*:\s*/, $line, 2;
    if($key eq "processor") {
      $proc = $val;
      $ret[$proc] = {};
      next;
    }

    $ret[$proc]->{$key} = $val;
  }

  return \@ret;
}

1;
