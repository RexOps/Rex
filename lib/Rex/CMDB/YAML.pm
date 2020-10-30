#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::YAML;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use base qw(Rex::CMDB::Base);

use Rex::Commands -no => [qw/get/];
use Rex::Logger;
use YAML;
use Data::Dumper;
use Hash::Merge qw/merge/;

require Rex::Commands::File;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  $self->{merger} = Hash::Merge->new();

  if ( !defined $self->{merge_behavior} ) {
    $self->{merger}->specify_behavior(
      {
        SCALAR => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { $_[0] },
        },
        ARRAY => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { $_[0] },
        },
        HASH => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) },
        },
      },
      'REX_DEFAULT',
    ); # first found value always wins

    $self->{merger}->set_behavior('REX_DEFAULT');
  }
  else {
    if ( ref $self->{merge_behavior} eq 'HASH' ) {
      $self->{merger}
        ->specify_behavior( $self->{merge_behavior}, 'USER_DEFINED' );
      $self->{merger}->set_behavior('USER_DEFINED');
    }
    else {
      $self->{merger}->set_behavior( $self->{merge_behavior} );
    }
  }

  bless( $self, $proto );

  return $self;
}

sub get {
  my ( $self, $item, $server ) = @_;

  $server = $self->__get_hostname_for($server);

  my $result = {};

  if ( $self->__cache->valid( $self->__cache_key() ) ) {
    $result = $self->__cache->get( $self->__cache_key() );
  }
  else {

    my @files = $self->_get_cmdb_files( $item, $server );

    Rex::Logger::debug( Dumper( \@files ) );

    # configuration variables
    my $config_values = Rex::Config->get_all;
    my %template_vars;
    for my $key ( keys %{$config_values} ) {
      if ( !exists $template_vars{$key} ) {
        $template_vars{$key} = $config_values->{$key};
      }
    }
    $template_vars{environment} = Rex::Commands::environment();

    for my $file (@files) {
      Rex::Logger::debug("CMDB - Opening $file");
      if ( -f $file ) {

        my $content = eval { local ( @ARGV, $/ ) = ($file); <>; };
        my $t       = Rex::Config->get_template_function();
        $content .= "\n"; # for safety
        $content = $t->( $content, \%template_vars );

        my $ref = YAML::Load($content);

        $result = $self->{merger}->merge( $result, $ref );
      }
    }
  }

  if ( defined $item ) {
    return $result->{$item};
  }
  else {
    return $result;
  }

}

sub _get_cmdb_files {
  my ( $self, $item, $server ) = @_;

  $server = $self->__get_hostname_for($server);

  my @files;

  if ( !ref $self->{path} ) {
    my $env          = Rex::Commands::environment();
    my $server_file  = "$server.yml";
    my $default_file = 'default.yml';
    @files = (
      File::Spec->join( $self->{path}, $env, $server_file ),
      File::Spec->join( $self->{path}, $env, $default_file ),
      File::Spec->join( $self->{path}, $server_file ),
      File::Spec->join( $self->{path}, $default_file ),
    );
  }
  elsif ( ref $self->{path} eq "CODE" ) {
    @files = $self->{path}->( $self, $item, $server );
  }
  elsif ( ref $self->{path} eq "ARRAY" ) {
    @files = @{ $self->{path} };
  }

  my $os = Rex::Hardware::Host->get_operating_system();

  @files = map {
    $self->_parse_path( $_, { hostname => $server, operatingsystem => $os, } )
  } @files;

  return @files;
}

1;

__END__

=head1 NAME

Rex::CMDB::YAML - YAML-based CMDB provider for Rex

=head1 DESCRIPTION

This module collects and merges data from a set of YAML files to provide configuration management database for Rex.

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

=head1 CONFIGURATION AND ENVIRONMENT

=head2 path

The path used to look for CMDB files. It supports various use cases depending on the type of data passed to it.

=over 4

=item * Scalar

 set cmdb => {
   type => 'YAML',
   path => 'path/to/cmdb',
 };

If a scalar is used, it tries to look up a few files under the given path:

 path/to/cmdb/{environment}/{hostname}.yml
 path/to/cmdb/{environment}/default.yml
 path/to/cmdb/{hostname}.yml
 path/to/cmdb/default.yml

=item * Array reference

 set cmdb => {
   type => 'YAML',
   path => [ 'cmdb/{hostname}.yml', 'cmdb/default.yml', ],
 };

If an array reference is used, it tries to look up the mentioned files in the given order.

=item * Code reference

 set cmdb => {
   type => 'YAML',
   path => sub {
     my ( $provider, $item, $server ) = @_;
     my @files = ( "$server.yml", "$item.yml" );
     return @files;
   },
 };

If a code reference is passed, it should return a list of files that would be looked up in the same order. The code reference gets the CMDB provider instance, the item, and the server as parameters.

=back

When the L<0.51 feature flag|Rex#0.51> or later is used, the default value of the C<path> option is:

 [qw(
   cmdb/{operatingsystem}/{hostname}.yml
   cmdb/{operatingsystem}/default.yml
   cmdb/{environment}/{hostname}.yml
   cmdb/{environment}/default.yml
   cmdb/{hostname}.yml
   cmdb/default.yml
 )]

The path specification supports macros enclosed within curly braces, which are dynamically expanded during runtime. By default, the valid macros are L<Rex::Hardware> variables, C<{server}> for the server name of the current connection, and C<{environment}> for the current environment.

Please note that the default environment is, well, C<default>.

You can define additional CMDB paths via the C<-O> command line option by using a semicolon-separated list of C<cmdb_path=$path> key-value pairs:

 rex -O 'cmdb_path=cmdb/{domain}.yml;cmdb_path=cmdb/{domain}/{hostname}.yml;' taskname

Those additional paths will be prepended to the current list of CMDB paths (so the last one specified will get on top, and thus checked first).

=head2 merge_behavior

This CMDB provider looks up the specified files in order, and returns the requested data. If multiple files specify the same data for a given item, then the first instance of the data will be returned by default.

Rex uses L<Hash::Merge> internally to merge the data found on different levels of the CMDB hierarchy. Any merge strategy supported by that module can be specified to override the default one. For example one of the built-in strategies:

 set cmdb => {
   type           => 'YAML',
   path           => 'cmdb',
   merge_behavior => 'LEFT_PRECEDENT',
 };

Or even custom ones:

 set cmdb => {
   type           => 'YAML',
   path           => 'cmdb',
   merge_behavior => {
     SCALAR => sub {},
     ARRAY  => sub {},
     HASH   => sub {},
 };

For the full list of options, please see the documentation of Hash::Merge.

=cut
