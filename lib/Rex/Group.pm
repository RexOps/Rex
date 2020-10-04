#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Group;

use strict;
use warnings;

# VERSION

use Rex::Logger;

use attributes;
use Rex::Group::Entry::Server;

use vars qw(%groups);
use List::MoreUtils 0.416 qw(uniq);
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );
  for my $srv ( @{ $self->{servers} } ) {
    $srv->append_to_group( $self->{name} );
  }

  return $self;
}

sub get_servers {
  my ($self) = @_;

  my @servers = map { ref( $_->to_s ) eq "CODE" ? &{ $_->to_s } : $_ }
    @{ $self->{servers} };

  return uniq @servers;
}

sub set_auth {
  my ( $self, %data ) = @_;
  $self->{auth} = \%data;

  map { $_->set_auth( %{ $self->get_auth } ) } $self->get_servers;
}

sub get_auth {
  my ($self) = @_;
  return $self->{auth};
}

################################################################################
# STATIC FUNCTIONS
################################################################################

# Creates a new server group
# Possible calls:
#   create_group(name => "g1", "srv1", "srv2");
#   create_group(name => "g1", Rex::Group::Entry::Server->new(name => "srv1"), "srv2");
#   create_group(name => "g1", "srv1" => { user => "other" }, "srv2");
sub create_group {
  my $class      = shift;
  my $group_name = shift;
  my @server     = uniq grep { defined } @_;

  my @server_obj;
  for ( my $i = 0 ; $i <= $#server ; $i++ ) {
    next if ref $server[$i] eq 'HASH'; # already processed by previous loop

    # if argument is already a Rex::Group::Entry::Server
    if ( ref $server[$i] && $server[$i]->isa("Rex::Group::Entry::Server") ) {
      push @server_obj, $server[$i];
      next;
    }

    # if next argument is a HashRef, use it as options for the server
    my %options =
      ( $i < $#server and ref $server[ $i + 1 ] eq 'HASH' )
      ? %{ $server[ $i + 1 ] }
      : ();

    my $obj = Rex::Group::Entry::Server->new( name => $server[$i], %options );
    push @server_obj, $obj;
  }

  $groups{$group_name} =
    Rex::Group->new( servers => \@server_obj, name => $group_name );
}

# returns the servers in the group
sub get_group {
  my $class      = shift;
  my $group_name = shift;

  if ( exists $groups{$group_name} ) {
    return $groups{$group_name}->get_servers;
  }

  return ();
}

sub is_group {
  my $class      = shift;
  my $group_name = shift;

  if ( defined $groups{$group_name} ) { return 1; }
  return 0;
}

sub get_groups {
  my $class = shift;
  my %ret   = ();

  for my $key ( keys %groups ) {
    $ret{$key} = [ $groups{$key}->get_servers ];
  }

  return %ret;
}

sub get_group_object {
  my $class = shift;
  my $name  = shift;

  return $groups{$name};
}

1;
