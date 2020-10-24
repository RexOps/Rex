#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Common;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
require Rex::Config;
use Rex::Resource;
use Data::Dumper;
use Symbol;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(emit resource resource_name changed created removed);

sub changed { return "changed"; }
sub created { return "created"; }
sub removed { return "removed"; }

sub emit {
  my ( $type, $message ) = @_;
  if ( !Rex::Resource->is_inside_resource ) {
    die "emit() only allowed inside resource.";
  }

  $message ||= "";

  Rex::Logger::debug( "Emiting change: " . $type . " - $message." );

  if ( $type eq changed ) {
    current_resource()->changed(1);
  }

  if ( $type eq created ) {
    current_resource()->created(1);
  }

  if ( $type eq removed ) {
    current_resource()->removed(1);
  }

  if ($message) {
    current_resource()->message($message);
  }
}

=over 4

=item resource($name, $function)

=cut

sub resource {
  my ( $name, $options, $function ) = @_;
  my $name_save = $name;

  my $caller_pkg = caller;

  if ( ref $options eq "CODE" ) {
    $function = $options;
    $options  = {};
  }

  if ( $name_save !~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ ) {
    Rex::Logger::info(
      "Please use only the following characters for resource names:", "warn" );
    Rex::Logger::info( "  A-Z, a-z, 0-9 and _", "warn" );
    Rex::Logger::info( "Also the resource should start with A-Z or a-z",
      "warn" );
    die "Wrong resource name syntax.";
  }

  my ( $class, $file, @tmp ) = caller;
  my $res = Rex::Resource->new(
    type         => "${class}::$name",
    name         => $name,
    display_name => (
      $options->{name}
        || ( $options->{export} ? $name : "${caller_pkg}::${name}" )
    ),
    cb => $function
  );

  my $func = sub {
    $res->call(@_);
  };

  if (!$class->can($name)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    if ( $class ne "main" && $class ne "Rex::CLI" ) {

      # if not in main namespace, register the task as a sub
      Rex::Logger::debug(
        "Registering resource (not main namespace): ${class}::$name_save");
    }
    else {
      Rex::Logger::debug("Registering resource: ${class}::$name_save");
    }

    my $code            = $_[-2];
    my $ref_to_resource = qualify_to_ref( $name_save, $class );
    *{$ref_to_resource} = $func;
  }

  if ( exists $options->{export} && $options->{export} ) {

    # register in caller namespace
    my $ref_to_ISA    = qualify_to_ref( 'ISA',    $caller_pkg );
    my $ref_to_EXPORT = qualify_to_ref( 'EXPORT', $caller_pkg );
    push @{ *{$ref_to_ISA} }, "Rex::Exporter"
      unless ( grep { $_ eq "Rex::Exporter" } @{ *{$ref_to_ISA} } );
    push @{ *{$ref_to_EXPORT} }, $name_save;
  }
}

sub resource_name {
  Rex::Config->set( resource_name => current_resource()->{res_name} );
  return current_resource()->{res_name};
}

sub resource_ensure {
  my ($option) = @_;
  $option->{ current_resource()->{res_ensure} }->();
}

sub current_resource {
  return $Rex::Resource::CURRENT_RES[-1];
}

=back

=cut

1;
