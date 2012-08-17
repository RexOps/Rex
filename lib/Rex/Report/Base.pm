#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Report::Base;
   
use strict;
use warnings;

use Rex::Logger;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub report {
   my ($self, $msg) = @_;
   Rex::Logger::info($msg);

   return length($msg);
}

1;
