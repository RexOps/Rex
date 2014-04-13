#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::FreeBSD;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
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

  i_run "/usr/local/etc/rc.d/$service onestart >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub restart {
  my($self, $service) = @_;

  i_run "/usr/local/etc/rc.d/$service onerestart >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub stop {
  my($self, $service) = @_;

  i_run "/usr/local/etc/rc.d/$service onestop >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub reload {
  my($self, $service) = @_;

  i_run "/usr/local/etc/rc.d/$service onereload >/dev/null";

  if($? == 0) {
    return 1;
  }

  return 0;
}

sub status {
  my($self, $service) = @_;

  i_run "/usr/local/etc/rc.d/$service onestatus >/dev/null";

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
  elsif($what =~ /^start/ || $what =~ m/^run/) {
    $self->start($service);
    append_if_no_such_line "/etc/rc.conf", "${service}_enable=\"YES\"\n";
  }

  return 1;
}

sub action {
  my ($self, $service, $action) = @_;

  i_run "/usr/local/etc/rc.d/$service $action >/dev/null";
  if($? == 0) { return 1; }
}

1;
