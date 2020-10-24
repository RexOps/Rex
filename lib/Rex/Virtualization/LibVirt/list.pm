#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::list;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

use Data::Dumper;

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  my @domains;

  if ( $arg1 eq "all" ) {
    @domains = i_run "virsh -c $uri list --all --name", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running virsh list --all --name");
    }
  }
  elsif ( $arg1 eq "running" ) {
    @domains = i_run "virsh -c $uri list --name", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running virsh list --name");
    }
  }
  else {
    return;
  }

  my @ret = ();
  for my $name (@domains) {
    my %data = map { my ( $key, $val ) = split( /:\s*/, $_ ); ( $key, $val ); }
      i_run "virsh -c $uri dominfo '$name'", fail_ok => 1;

    push(
      @ret,
      {
        id     => $data{Id},
        name   => $data{Name},
        status => $data{State}
      }
    );
  }

  return \@ret;

}

1;
