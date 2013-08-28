#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::Redhat::systemd;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
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

   i_run "systemctl start $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   i_run "systemctl restart $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   i_run "systemctl stop $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   i_run "systemctl reload $service >/dev/null";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;
   $service = _prepare_service_name($service);

   i_run "systemctl status $service >/dev/null";

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
      i_run "systemctl disable $service";
   }
   elsif($what =~ /^start/ || $what =~ m/^run/) {
      $self->start($service);
      i_run "systemctl enable $service";
   }

   if($? == 0) { return 1; } else { return 0; }
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

   i_run "systemctl $action $service >/dev/null";
   if($? == 0) { return 1; }
}

1;
