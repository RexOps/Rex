#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::option;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

my $FUNC_MAP = {
  max_memory => "setmaxmem",
  memory     => "setmem",
};

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("setting some options for: $dom");

  for my $opt ( keys %opt ) {
    my $val = $opt{$opt};

    unless ( exists $FUNC_MAP->{$opt} ) {
      Rex::Logger::info("$opt can't be set right now.");
      next;
    }

    my $func = $FUNC_MAP->{$opt};
    i_run "virsh -c $uri $func '$dom' '$val'", fail_ok => 1;
    if ( $? != 0 ) {
      Rex::Logger::info( "Error setting $opt to $val on $dom ($@)", "warn" );
    }

  }

}

1;
