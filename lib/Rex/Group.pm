#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Group;

use strict;
use warnings;

use Rex::Logger;
use Rex::Group::Entry::Server;

use vars qw(%groups);
use Data::Dumper;

sub create_group {
   my $class = shift;
   my $group_name = shift;
   my @server = @_;

   @{$groups{$group_name}} = map { $_ = Rex::Group::Entry::Server->new(name => $_); } @server;
}

sub get_group {
   my $class = shift;
   my $group_name = shift;

   return @{$groups{$group_name}};
}

sub is_group {
   my $class = shift;
   my $group_name = shift;

   if(defined $groups{$group_name}) { return 1; }
   return 0;
}

sub get_groups {
   my $class = shift;
   return %groups;
}

1;
