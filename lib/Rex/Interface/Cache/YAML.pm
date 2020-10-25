#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Cache::YAML;

use 5.010001;
use strict;
use warnings;
use Rex::Interface::Cache::Base;
use base qw(Rex::Interface::Cache::Base);

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Commands;
require Rex::Commands::Fs;
require YAML;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub save {
  my ($self) = @_;

  my $path = Rex::Commands::get("cache_path") || ".cache";

  if ( exists $ENV{REX_CACHE_PATH} ) {
    $path = $ENV{REX_CACHE_PATH};
  }

  if ( !-d $path ) {
    Rex::Commands::LOCAL( sub { mkdir $path } );
  }

  open( my $fh, ">", "$path/" . Rex::Commands::connection->server . ".yml" )
    or die($!);
  print $fh YAML::Dump( $self->{__data__} );
  close($fh);
}

sub load {
  my ($self) = @_;

  my $path = Rex::Commands::get("cache_path") || ".cache";

  if ( exists $ENV{REX_CACHE_PATH} ) {
    $path = $ENV{REX_CACHE_PATH};
  }

  my $file_name = "$path/" . Rex::Commands::connection->server . ".yml";

  if ( !-f $file_name ) {

    # no cache found
    return;
  }

  my $yaml = eval { local ( @ARGV, $/ ) = ($file_name); <>; };

  $yaml .= "\n";

  $self->{__data__} = YAML::Load($yaml);
}

1;
