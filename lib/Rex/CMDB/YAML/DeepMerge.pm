#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::YAML::DeepMerge;

use strict;
use warnings;

# VERSION

use base qw(Rex::CMDB::YAML::Default);

use Rex::Commands -no => [qw/get/];
use Rex::Logger;
use YAML;
use Data::Dumper;
use Hash::Merge qw/merge/;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  $self->{merge_behavior} ||= 'LEFT_PRECEDENT';

  bless( $self, $proto );
  return $self;
}

sub get {
  my ( $self, $item, $server ) = @_;

  my (@files);

  my $merge = Hash::Merge->new( $self->{merge_behavior} );

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

  my $global_cmdb = {};

  for my $file (@files) {
    Rex::Logger::debug("CMDB - Opening $file");
    if ( -f $file ) {
      my $ref;
      eval {
        $ref = YAML::LoadFile($file);
        1;
      } or do {
        die "Error parsing YAML file: $file";
      };

      $all = $merge->merge( $all, $ref );
    }
  }

  if ( !$item ) {
    return $all;
  }
  else {
    return $all->{$item};
  }

  Rex::Logger::debug("CMDB - no item ($item) found");

  return;
}

1;
