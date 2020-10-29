#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::CMDB - Function to access the CMDB (configuration management database)

=head1 DESCRIPTION

This module exports a function to access a CMDB via a common interface. When the L<0.51 feature flag|Rex#0.51> or later is used, the CMDB is enabled by default with L<Rex::CMDB::YAML> as the default provider.

=head1 SYNOPSIS

 use Rex::CMDB;
 
 set cmdb => {
   type           => 'YAML',
   path           => [ 'cmdb/{hostname}.yml', 'cmdb/default.yml', ],
   merge_behavior => 'LEFT_PRECEDENT',
 };
 
 task 'prepare', 'server1', sub {
   my %all_information          = get cmdb;
   my $specific_item            = get cmdb('item');
   my $specific_item_for_server = get cmdb( 'item', 'server' );
 };

=head1 EXPORTED FUNCTIONS

=cut

package Rex::CMDB;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands;
use Rex::Value;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(cmdb);

my $CMDB_PROVIDER;

=head2 set cmdb

 set cmdb => {
   type => 'YAML',
   %provider_options,
 };

Instantiate a specific C<type> of CMDB provider with the given options. Returns the provider instance.

Please consult the documentation of the given provider for their supported options.

=cut

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

    my $klass = $option->{type};

    if ( !$klass ) {

      # no cmdb set
      return;
    }

    if ( $klass !~ m/::/ ) {
      $klass = "Rex::CMDB::$klass";
    }

    eval "use $klass";

    if ($@) {
      die("CMDB provider ($klass) not found: $@");
    }

    $CMDB_PROVIDER = $klass->new( %{$option} );
  }
);

=head2 cmdb([$item, $server])

Function to query a CMDB.

If called without arguments, it returns the full CMDB data structure for the current connection.

If only a defined C<$item> is passed, it returns only the value for the given CMDB item, for the current connection.

If only a defined C<$server> is passed, it returns the whole CMDB data structure for the given server.

If both C<$item> and C<$server> are defined, it returns the given CMDB item for the given server.

The value returned is a L<Rex::Value>, so you may need to use the C<get cmdb(...)> form if you'd like to assign the result to a Perl variable:

 task 'prepare', 'server1', sub {
   my %all_information          = get cmdb;
   my $specific_item            = get cmdb('item');
   my $specific_item_for_server = get cmdb( 'item', 'server' );
 };

If caching is enabled, this function caches the full data structure for the given server under the C<cmdb/$CMDB_PROVIDER/$server> cache key after the first query.

=cut

sub cmdb {
  my ( $item, $server ) = @_;

  return if !cmdb_active();

  $CMDB_PROVIDER->__warm_up_cache_for($server);

  my $value = $CMDB_PROVIDER->get( $item, $server );

  if ( defined $value ) {
    return Rex::Value->new( value => $value );
  }
  else {
    Rex::Logger::debug("CMDB - no item ($item) found");
    return;
  }
}

sub cmdb_active {
  return ( $CMDB_PROVIDER ? 1 : 0 );
}

1;
