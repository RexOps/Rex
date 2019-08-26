#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Common;

use strict;
use warnings;

# VERSION

require Exporter;
require Rex::Config;
use Rex::Commands::Gather;
use Rex::Resource;
use Data::Dumper;
use MooseX::Params::Validate;
use Hash::Merge qw/merge/;
use Rex::MultiSub::Resource;

use base qw(Exporter);
use vars qw(@EXPORT);
use Carp;

@EXPORT =
  qw(emit resource resource_name changed created removed get_resource_provider
  state_good state_changed state_created state_removed state_failed state_timeout
  resolve_resource_provider
);

sub changed { return "changed"; }
sub created { return "created"; }
sub removed { return "removed"; }

sub state_good    { return "good"; }
sub state_failed  { return "failed"; }
sub state_changed { return "changed"; }
sub state_created { return "created"; }
sub state_removed { return "removed"; }
sub state_timeout { return "timeout"; }

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

my $__lookup_table;

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

  my $sub = Rex::MultiSub::Resource->new(
    name        => $name_save,
    function    => $function,
    params_list => $options->{params_list},
  );

  my ( $class, $file, @tmp ) = caller;

  $sub->export( $class, $options->{export} );
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

sub get_resource_provider {
  my ( $os, $os_name ) = @_;
  my ($pkg) = caller;

  if ( is_redhat($os_name) ) {
    $os_name = "redhat";
  }

  elsif ( is_ubuntu($os_name) ) {
    $os_name = "ubuntu";
  }

  elsif ( is_debian($os_name) ) {
    $os_name = "debian";
  }

  elsif ( is_gentoo($os_name) ) {
    $os_name = "gentoo";
  }

  elsif ( is_suse($os_name) ) {
    $os_name = "suse";
  }

  elsif ( is_alt($os_name) ) {
    $os_name = "alt";
  }

  elsif ( is_mageia($os_name) ) {
    $os_name = "mageia";
  }

  elsif ( is_arch($os_name) ) {
    $os_name = "arch";
  }

  elsif ( is_openwrt($os_name) ) {
    $os_name = "openwrt";
  }

  else {
    die "No module found for $os_name.";
  }

  my $try_load = sub {
    my @mods = @_;

    my $ret;
    for my $mod (@mods) {
      Rex::Logger::debug("Try to load provider: $mod");
      eval {
        $mod->require;
        $ret = $mod;
        1;
      } or do {
        Rex::Logger::debug("Failed loading provider: $mod\n$@");
        $ret = undef;
      };

      return $ret if ($ret);
    }
  };

  my $provider_pkg = $try_load->(
    "${pkg}::Provider::" . lc("${os}::${os_name}"),
    "${pkg}::Provider::" . lc("${os}::default"),
    "${pkg}::Provider::" . lc($os)
  );

  return $provider_pkg;
}

sub resolve_resource_provider {
  my ($provider) = @_;

  if ( $provider =~ m/^::/ ) {
    my @call = caller;
    return $call[0] . "::Provider$provider";
  }

  return $provider;
}

=back

=cut

1;
