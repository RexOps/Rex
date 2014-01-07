#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Group;

use strict;
use warnings;

use Rex::Logger;

use attributes;
use Rex::Group::Entry::Server;

use vars qw(%groups);
use List::MoreUtils qw(uniq);
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}


sub get_servers {
   my ($self) = @_;

   my @servers = map { ref($_->to_s) eq "CODE" ? &{ $_->to_s } : $_ } @{ $self->{servers} };

   return @servers;
}

sub set_auth {
   my ($self, %data) = @_;
   $self->{auth} = \%data;

   map { $_->set_auth(%{ $self->get_auth }) } $self->get_servers;
}

sub get_auth {
   my ($self) = @_;
   return $self->{auth};
}


################################################################################
# STATIC FUNCTIONS
################################################################################

sub create_group {
   my $class = shift;
   my $group_name = shift;
   my @server = @_;

   $groups{$group_name} = Rex::Group->new(servers => [ map {
                                                              if(ref($_) ne "Rex::Group::Entry::Server") {
                                                                 $_ = Rex::Group::Entry::Server->new(name => $_)
                                                              }
                                                              else {
                                                                 $_;
                                                              }
                                                           } uniq(@server) 
                                                     ]
                                         );
}

# returns the servers in the group
sub get_group {
   my $class = shift;
   my $group_name = shift;

   if(exists $groups{$group_name}) {
      return $groups{$group_name}->get_servers;
   }

   return ();
}

sub is_group {
   my $class = shift;
   my $group_name = shift;

   if(defined $groups{$group_name}) { return 1; }
   return 0;
}

sub get_groups {
   my $class = shift;
   my %ret = ();
   
   for my $key (keys %groups) {
      $ret{$key} = [ $groups{$key}->get_servers ];
   }

   return %ret;
}

sub get_group_object {
   my $class = shift;
   my $name = shift;

   return $groups{$name};
}

1;
