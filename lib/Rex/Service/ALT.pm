#
# ALT sevice control support
#
package Rex::Service::ALT;

use strict;
use warnings;

use Rex::Commands::Run;
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

   run "/sbin/service $service start >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;

   run "/sbin/service $service restart >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;

   run "/sbin/service $service stop >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;

   run "/sbin/service $service reload >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;

   run "/sbin/service $service status >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      run "/sbin/chkconfig $service off";
   }
   elsif($what =~ /^start/) {
      $self->start($service);
      run "/sbin/chkconfig $service on";
   }
}

sub action {
   my ($self, $service, $action) = @_;

   run "/sbin/service $service $action >/dev/null";
   if($? == 0) { return 1; }
}


1;
