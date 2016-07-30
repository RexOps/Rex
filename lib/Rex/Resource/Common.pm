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

use base qw(Exporter);
use vars qw(@EXPORT);
use Carp;

@EXPORT =
  qw(emit resource resource_name changed created removed get_resource_provider);

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

  push @{ $__lookup_table->{$name} },
    {
    options => $options,
    code    => $function,
    };

  my ( $class, $file, @tmp ) = caller;

  # this function is responsible to lookup the right resource code
  # every resource can have multiple resource code depending on its parameters.
  my $call_func = sub {
    my $app = Rex->instance;

    $app->output->print_s( { title => $name, msg => $_[0] } );

    my @errors;
    eval {
      my $found = 0;
      for my $f (
        sort {
          scalar( @{ $b->{options}->{params_list} } ) <=>
            scalar( @{ $a->{options}->{params_list} } )
        } @{ $__lookup_table->{$name} }
        )
      {
        my %args;
        eval {
          my @modified_args = @_;
          my $name          = shift @modified_args;

          # some defaults maybe a coderef, so we need to execute this now
          my @_x = @{ $f->{options}->{params_list} };
          my %_x = @_x;
          for my $k ( keys %_x ) {
            if ( ref $_x{$k}->{default} eq "CODE" ) {
              $_x{$k}->{default} = $_x{$k}->{default}->(@_);
            }
          }
          %args = validated_hash(
            \@modified_args, %_x,
            MX_PARAMS_VALIDATE_NO_CACHE    => 1,
            MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
          );

          $found = 1;
          1;
        } or do {
          push @errors, $@;

          # print "Err: $@\n";
          # TODO catch no "X parameter was given" errors
          next;
        };

        # TODO check for common parameters like
        # * timeout
        # * only_notified
        # * only_if
        # * unless
        # * creates
        # * on_change
        # * ensure

        my $res = Rex::Resource->new(
          type         => "${class}::$name",
          name         => $name,
          display_name => (
            $options->{name}
              || ( $options->{export} ? $name : "${caller_pkg}::${name}" )
          ),
          cb => $f->{code},
        );

        my $c = Rex::Controller::Resource->new( app => $app, params => \%args );
        my @args = @_;
        $app->push_run_stage(
          $c,
          sub {
            $res->call( $c, @args );
          }
        );
        last;
      }
      if ( !$found ) {
        my @err_msg;
        for my $err (@errors) {
          my ($fline) = split( /\n/, $err );
          push @err_msg, $fline;
        }
        croak "Resource $name for provided parameter not found.\nErrors:\n"
          . join( "\n", @err_msg );
      }
      1;
    } or do {
      $app->output->endln_failed();
      die "Error executing resource: $name.\nError: $@\n";
    };

    $app->output->endln_ok();
  };

  # this is the code that gets registered into the namespace
  my $func = sub {

    # test if first parameter to resource is a hash
    # if so, we have multiple instances of this resource and we need to call
    # every of them.
    #
    # Example:
    # kmod {
    #   foo => { ensure => "present", },
    #   bar => { ensure => "present", },
    # };
    if ( ref $_[0] eq "HASH" ) {
      my ($res_hash) = @_;

      for my $n ( keys %{$res_hash} ) {
        my $this_p = $res_hash->{$n};

        # test if the second parameter is also a hash, this means we need to
        # merge this hash as default values into the parameters of the
        # first hash.
        if ( $_[1] && ref $_[1] eq "HASH" ) {
          $this_p = merge( $this_p, $_[1] );
        }

        # now we call the resource code for each one of the first hash.
        $call_func->( $n, %{$this_p} );
      }

      # nothing to do anymore, so we can just return.
      # a resource doesn't have a specified return value.
      return undef;
    }

    # test if the first parameter to resource is an array
    # if so, we have to iterate over the array and call the resource code for
    # each of them.
    if ( ref $_[0] eq "ARRAY" ) {
      my $all_res = shift;
      for my $n ( @{$all_res} ) {
        $call_func->( $n, @_ );
      }

      # nothing to do anymore, so we can just return.
      # a resource doesn't have a specified return value.
      return undef;
    }

    # default resource call
    $call_func->(@_);
  };

  if (!$class->can($name)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    no strict 'refs';
    Rex::Logger::debug("Registering resource: ${class}::$name_save");

    my $code = $_[-2];
    *{"${class}::$name_save"} = $func;
    use strict;
  }
  elsif ( ( $class ne "main" && $class ne "Rex::CLI" )
    && !$class->can($name_save)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    # if not in main namespace, register the task as a sub
    no strict 'refs';
    Rex::Logger::debug(
      "Registering resource (not main namespace): ${class}::$name_save");
    my $code = $_[-2];
    *{"${class}::$name_save"} = $func;

    use strict;
  }

  if ( exists $options->{export} && $options->{export} ) {
    no strict 'refs';

    # register in caller namespace
    push @{ $caller_pkg . "::ISA" }, "Rex::Exporter"
      unless ( grep { $_ eq "Rex::Exporter" } @{ $caller_pkg . "::ISA" } );
    push @{ $caller_pkg . "::EXPORT" }, $name_save;
    use strict;
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

sub get_resource_provider {
  my ( $os, $os_name ) = @_;
  my ($pkg) = caller;

  if ( is_redhat($os_name) ) {
    $os_name = "redhat";
  }

  elsif ( is_debian($os_name) ) {
    $os_name = "debian";
  }

  elsif ( is_ubuntu($os_name) ) {
    $os_name = "ubuntu";
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

=back

=cut

1;
