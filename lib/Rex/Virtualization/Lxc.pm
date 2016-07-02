#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Virtualization::Lxc - Linux Containers Virtualization Module

=head1 DESCRIPTION

With this module you can manage Linux Containers.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;

 set virtualization => "Lxc";

 use Data::Dumper;

 print Dumper vm list => "all";
 print Dumper vm list => "active";


=cut

package Rex::Virtualization::Lxc;

use strict;
use warnings;

our $VERSION = '1.4.0'; # VERSION

use Rex::Virtualization::Base;
use base qw(Rex::Virtualization::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

1;
