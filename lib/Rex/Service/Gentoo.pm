#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Gentoo;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
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

  i_run "/etc/init.d/$service start >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub restart {
  my($self, $service) = @_;

  i_run "/etc/init.d/$service restart >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub stop {
  my($self, $service) = @_;

  i_run "/etc/init.d/$service stop >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub reload {
  my($self, $service) = @_;

  i_run "/etc/init.d/$service reload >/dev/null", nohup => 1;

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub status {
  my($self, $service) = @_;

  i_run "/etc/init.d/$service status >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub ensure {
  my ($self, $service, $what) = @_;

  if($what =~  /^stop/) {
    $self->stop($service);
    i_run "rc-update del $service";
  }
  elsif($what =~ /^start/ || $what =~ m/^run/) {
    $self->start($service);
    i_run "rc-update add $service";
  }

  if($? == 0) { return 1; } else { return 0; }
}

sub action {
  my ($self, $service, $action) = @_;

  i_run "/etc/init.d/$service $action >/dev/null", nohup => 1;
  if($? == 0) { return 1; }
}

1;
