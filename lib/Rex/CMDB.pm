#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::CMDB - Function to access the CMDB.

=head1 DESCRIPTION

This module exports a function to access a CMDB via a common interface.

=head1 SYNOPSIS

 task "prepare", "server1", sub {
   my $virtual_host = cmdb("vhost");
   my %all_information = cmdb;
 };


=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::CMDB;

use strict;
use warnings;

# VERSION

use Rex::Commands;
use Rex::Value;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(cmdb);

my $CMDB_PROVIDER;

Rex::Config->register_set_handler(
  "cmdb" => sub {
    my ($option) = @_;

    my %args = Rex::Args->getopts;

    if ( exists $args{O} ) {
      for my $itm ( split( /;/, $args{O} ) ) {
        my ( $key, $val ) = split( /=/, $itm );
        if ( $key eq "cmdb_path" ) {
          if ( ref $option->{path} eq "ARRAY" ) {
            unshift @{ $option->{path} }, $val;
          }
          else {
            $option->{path} = [$val];
          }
        }
      }
    }

    $CMDB_PROVIDER = $option;
  }
);

=item cmdb([$item, $server])

Function to query a CMDB. If this function is called without $item it should return a hash containing all the information for the requested server. If $item is given it should return only the value for $item.

 task "prepare", "server1", sub {
   my $virtual_host = cmdb("vhost");
   my %all_information = cmdb;
 };

=cut

sub cmdb {
  my ( $item, $server ) = @_;
  $server ||= connection->server;

  my $klass = $CMDB_PROVIDER->{type};

  if ( !$klass ) {

    # no cmdb set
    return;
  }

  if ( $klass !~ m/::/ ) {
    $klass = "Rex::CMDB::$klass";
  }

  if ( $klass eq "Rex::CMDB::YAML" ) {
    $klass = "Rex::CMDB::YAML::Default";
  }

  eval "use $klass";
  if ($@) {
    die("CMDB provider ($klass) not found: $@");
  }

  my $cmdb = $klass->new( %{$CMDB_PROVIDER} );
  return Rex::Value->new( value => ( $cmdb->get( $item, $server ) || undef ) );
}

sub cmdb_active {
  return ( $CMDB_PROVIDER ? 1 : 0 );
}

=back

=cut

1;
