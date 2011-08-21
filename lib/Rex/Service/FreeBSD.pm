#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::FreeBSD;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Logger;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub start {
   my($self, $service) = @_;

   run "/usr/local/etc/rc.d/$service onestart";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;

   run "/usr/local/etc/rc.d/$service onerestart";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;

   run "/usr/local/etc/rc.d/$service onestop";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;

   run "/usr/local/etc/rc.d/$service onereload";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;

   run "/usr/local/etc/rc.d/$service onestatus";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      delete_lines_matching "/etc/rc.conf", matching => qr/${service}_enable="YES"/;
   }
   elsif($what =~ /^start/) {
      $self->start($service);
      append_if_no_such_line "/etc/rc.conf", "${service}_enable=\"YES\"\n";
   }
}


1;
