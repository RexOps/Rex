#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SunOS::svcadm;

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

  i_run "svcadm enable $service >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub restart {
  my($self, $service) = @_;

  i_run "svcadm restart $service >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub stop {
  my($self, $service) = @_;

  i_run "svcadm disable $service >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub reload {
  my($self, $service) = @_;

  i_run "svcadm refresh $service >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub status {
  my($self, $service) = @_;

  my ($state) = grep { $_=$1 if /state\s+([a-z]+)/ } i_run "svcs -l $service";

  if($state eq "online") {
    return 1;
  }

  return 0;
}

sub ensure {
  my ($self, $service, $what) = @_;

  if($what =~  /^stop/) {
    $self->stop($service);
  }
  elsif($what =~ /^start/ || $what =~ m/^run/) {
    $self->start($service);
  }

  return 1;
}

sub action {
  my ($self, $service, $action) = @_;

  i_run "svcadm $action $service >/dev/null", nohup => 1;
  if($? == 0) { return 1; }
}

1;
