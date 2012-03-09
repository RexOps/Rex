#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::Redhat::systemd;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Logger;
use Rex::Commands::Fs;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub start {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   run "systemctl start $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   run "systemctl restart $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   run "systemctl stop $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   run "systemctl reload $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   run "systemctl status $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub ensure {
   my ($self, $service, $what) = @_;
   $service = _prepare_service_name($service);

   if($what =~  /^stop/) {
      $self->stop($service);
      run "systemctl disable $service";
   }
   elsif($what =~ /^start/) {
      $self->start($service);
      run "systemctl enable $service";
   }
}

# all systemd services must end with .service
# so it will be appended if there is no "." in the name.
sub _prepare_service_name {
   my ($service) = @_;

   unless($service =~ m/\./) {
      $service .= ".service";
   }

   return $service;
}

sub action {
   my ($self, $service, $action) = @_;

   run "systemctl $action $service >/dev/null";
   if($? == 0) { return 1; }
}

1;
