#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::YAML::Default;

use strict;
use warnings;

# VERSION

use base qw(Rex::CMDB::Base);

use Rex::Commands -no => [qw/get/];
use Rex::Logger;
use YAML;
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  if ( !$self->{path} ) {
    $self->{path} = [
      "cmdb/{operatingsystem}/{hostname}.yml",
      "cmdb/{operatingsystem}/default.yml",
      "cmdb/{environment}/{hostname}.yml",
      "cmdb/{environment}/default.yml",
      "cmdb/{hostname}.yml",
      "cmdb/default.yml",
    ];
  }

  bless( $self, $proto );
  return $self;
}

sub get {
  my ( $self, $item, $server ) = @_;

  # first open $server.yml
  # second open $environment/$server.yml
  # third open $environment/default.yml
  # forth open default.yml

  my (@files);

  if ( !ref $self->{path} ) {
    my $env       = environment;
    my $yaml_path = $self->{path};
    @files = (
      "$yaml_path/$env/$server.yml", "$yaml_path/$env/default.yml",
      "$yaml_path/$server.yml",      "$yaml_path/default.yml"
    );
  }
  elsif ( ref $self->{path} eq "CODE" ) {
    @files = $self->{path}->();
  }
  elsif ( ref $self->{path} eq "ARRAY" ) {
    @files = @{ $self->{path} };
  }

  @files = map { $self->_parse_path($_) } @files;

  my $all = {};
  Rex::Logger::debug( Dumper( \@files ) );

  for my $file (@files) {
    Rex::Logger::debug("CMDB - Opening $file");
    if ( -f $file ) {

      #my $content = eval { local ( @ARGV, $/ ) = ($file); <>; };
      #$content .= "\n";    # for safety

      my $ref;
      eval {
        $ref = YAML::LoadFile($file);
        1;
      } or do {
        die "Error parsing YAML file: $file";
      };

      if ( !$item ) {
        for my $key ( keys %{$ref} ) {
          if ( exists $all->{$key} ) {
            next;
          }
          $all->{$key} = $ref->{$key};
        }
      }

      if ( defined $item && exists $ref->{$item} ) {
        Rex::Logger::debug("CMDB - Found $item in $file");
        return $ref->{$item};
      }
    }
  }

  if ( !$item ) {
    return $all;
  }

  Rex::Logger::debug("CMDB - no item ($item) found");

  return;
}

1;
