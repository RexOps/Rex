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

  my @files = $self->_get_cmdb_files( $item, $server );

  my $all = {};
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

      $all = $self->{merger}->merge( $all, $ref );
    }
  }

  return $all;
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
