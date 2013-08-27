#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Report::Base;
   
use strict;
use warnings;

use Data::Dumper;
use Rex::Logger;
use Time::HiRes qw(time);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub report {
   my ($self, $msg) = @_;
   return 1;
}

sub register_reporting_hooks {}
sub write_report {}


1;
