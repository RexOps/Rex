#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::OpenBSD;

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

   run "/etc/rc.d/$service start";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;

   run "/etc/rc.d/$service restart";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;

   run "/etc/rc.d/$service stop";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;

   run "/etc/rc.d/$service reload";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;

   run "/etc/rc.d/$service status";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      delete_lines_matching "/etc/rc.conf", matching => qr/rc_scripts="\${rc_scripts} ${service}"/;
   }
   elsif($what =~ /^start/) {
      $self->start($service);
      append_if_no_such_line "/etc/rc.conf", "rc_scripts=\"\${rc_scripts} ${service}\"\n";
   }
}

sub action {
   my ($self, $service, $action) = @_;

   run "/etc/rc.d/$service $action";
   if($? == 0) { return 1; }
}

1;
