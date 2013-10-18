#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::OpenWrt;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Logger;

use Rex::Service::Debian;
use base qw(Rex::Service::Debian);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub status {
   my($self, $service) = @_;

   i_run "/sbin/start-stop-daemon -K -t -q -n $service";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      i_run "/etc/init.d/$service disable";
   }
   elsif($what =~ /^start/ || $what =~ m/^run/) {
      $self->start($service);
      i_run "/etc/init.d/$service enable";
   }

   if($? == 0) { return 1; } else { return 0; }
}

1;
