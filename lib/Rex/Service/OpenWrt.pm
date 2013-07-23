#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service::OpenWrt;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Logger;

use Rex::Service::Debian;
use base qw(Rex::Service::Debian);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub status {
   my($self, $service) = @_;

   Rex::Logger::info("status on openwrt not available.", "warn");
   return 1;
}

sub ensure {
   my ($self, $service, $what) = @_;

   if($what =~  /^stop/) {
      $self->stop($service);
      run "/etc/init.d/$service disable";
   }
   elsif($what =~ /^start/ || $what =~ m/^run/) {
      $self->start($service);
      run "/etc/init.d/$service enable";
   }
}

1;
