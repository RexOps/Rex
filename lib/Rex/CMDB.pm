#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::CMDB - Function to access the CMDB (configuration management database)

=head1 DESCRIPTION

This module exports a function to access a CMDB via a common interface.

=head1 SYNOPSIS

 use Rex::CMDB;
 
 set cmdb => {
     type => 'YAML',
     path => [ 
         'cmdb/{hostname}.yml',
         'cmdb/default.yml',
     ],
     merge_behavior => 'LEFT_PRECEDENT',
 };
 
 task "prepare", "server1", sub {
   my $virtual_host = cmdb("vhost");
   my %all_information = cmdb;
 };

=head1 EXPORTED FUNCTIONS

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

=item set cmdb

CMDB is enabled by default, with Rex::CMDB::YAML as default provider.

The path option specifies an ordered list of places to look for CMDB information. The path specification supports any Rex::Hardware variable as macros, when enclosed within curly braces. Macros are dynamically expanded during runtime. The default path settings is:

 [qw(
     cmdb/{operatingsystem}/{hostname}.yml
     cmdb/{operatingsystem}/default.yml
     cmdb/{environment}/{hostname}.yml
     cmdb/{environment}/default.yml
     cmdb/{hostname}.yml
     cmdb/default.yml
 )]

Please note that the default environment is, well, "default".

The CMDB module looks up the specified files in order and then returns the requested data. If multiple files specify the same data for a given case, then the first instance of the data will be returned by default.

Rex uses Hash::Merge internally to merge the data found on different levels of the CMDB hierarchy. Any merge strategy supported by that module can be specified to override the default one. For example one of the built-in strategies:

 merge_behavior => 'LEFT_PRECEDENCE'

Or even custom ones:

 merge_behavior => {
     SCALAR => { ... },
     ARRAY  => { ... },
     HASH   => { ... },
 }

For full list of options, please see the documentation of Hash::Merge.

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

    $CMDB_PROVIDER = $option;
  }
);

=head2 cmdb([$item, $server])

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

1;
