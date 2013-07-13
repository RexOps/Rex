#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::User::OpenWrt;

use strict;
use warnings;

use Rex::Logger;
require Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Helper::Path;

use Rex::User::Linux;
use base qw(Rex::User::Linux);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub rm_user {
   my ($self, $user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my $user_info = $self->get_user($user);

   if(exists $data->{delete_home} && $user_info->{home} && is_dir($user_info->{home})) {
      rmdir $user_info->{home};
   }

   run "sed -i '/^$user:.*/d' /etc/passwd && sed -i '/^$user:.*/d' /etc/shadow";
}

sub user_groups {
   my ($self, $user) = @_;

   Rex::Logger::debug("Getting group membership of $user");

   my $data_str = run "/usr/bin/id $user | perl -lne '\$_ =~ s/^.*groups=//; \@groups = \$_ =~ m/\\(([^\\)]+)\\)/g; print join(\" \", \@groups)'";
   if($? != 0) {
      die("Error getting  user list");
   }

   my $wantarray = wantarray();

   if(defined $wantarray && ! $wantarray) {
      # arrayref
      return [ split(/ /, $data_str) ];
   }

   return split(/ /, $data_str);
}

sub rm_group {
   my ($self, $group) = @_;
   run "sed -i '/^$group:.*/d' /etc/group";
}


1;
