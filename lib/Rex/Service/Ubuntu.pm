#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::Ubuntu;

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

   run "service $service start";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub restart {
   my($self, $service) = @_;

   run "service $service restart";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub stop {
   my($self, $service) = @_;

   run "service $service stop";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub reload {
   my($self, $service) = @_;

   run "service $service reload";

   if($? == 0) {
      return 1;
   }

   return 0;
}

sub status {
   my($self, $service) = @_;

   my @ret = run "service $service status";

   # bad... really bad ...
   if($? != 0) {
      return 0;
   }

   if(grep { /NOT running|stop\// } @ret) {
      return 0;
   }

   return 1;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      run "update-rc.d -f $service remove";
   }
   elsif($what =~ /^start/ || $what =~ m/^run/) {
      $self->start($service);
      run "update-rc.d $service defaults";
   }
}

sub action {
   my ($self, $service, $action) = @_;

   run "service $service $action";
   if($? == 0) { return 1; }
}

1;
