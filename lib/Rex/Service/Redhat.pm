#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Redhat;

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

  i_run "/etc/rc.d/init.d/$service start >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub restart {
  my($self, $service) = @_;

  # sometimes we need to sleep a little bit... because
  # the ssh channel gets closed too fast... i don't know why, yet.
  i_run "/etc/rc.d/init.d/$service restart >/dev/null ; f=\$?; sleep .1 ; exit \$f";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub stop {
  my($self, $service) = @_;

  i_run "/etc/rc.d/init.d/$service stop >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub reload {
  my($self, $service) = @_;

  i_run "/etc/rc.d/init.d/$service reload >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub status {
  my($self, $service) = @_;

  i_run "/etc/rc.d/init.d/$service status >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub ensure {
  my ($self, $service, $what) = @_;

  if($what =~  /^stop/) {
    $self->stop($service);
    i_run "chkconfig $service off";
  }
  elsif($what =~ /^start/ || $what =~ m/^run/) {
    $self->start($service);
    i_run "chkconfig $service on";
  }

  if($? == 0) { return 1; } else { return 0; }
}

sub action {
  my ($self, $service, $action) = @_;

  i_run "/etc/rc.d/init.d/$service $action >/dev/null";
  if($? == 0) { return 1; }
}


1;
