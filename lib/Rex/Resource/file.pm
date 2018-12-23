#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::file;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Data::Dumper;

use Carp;

# create the resource "file"
resource "file", {

  # export this resource to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this resource will have
  # rex is doing a type check here.
  params_list => [
    path => {
      isa => 'Str',

      # default is the name parameter (file $name;)
      default => sub { shift }
    },
    owner        => { isa => 'Str | Undef', default => undef },
    group        => { isa => 'Str | Undef', default => undef },
    mode         => { isa => 'Str | Undef', default => undef },
    content      => { isa => 'Str | Undef', default => undef },
    source       => { isa => 'Str | Undef', default => undef },
    no_overwrite => { isa => 'Bool', default => 0},
    ensure       => { isa => 'Str', default => sub { "present" }},
  ],
  },
  sub {
  my ( $name, %args ) = @_;

  # here we define the provider the resource should use. If someone want to use
  # a custom provider we will use this. Otherwise we try to detect the provider
  # automatically.
  my $provider = $args{provider}
    || "Rex::Resource::file::Provider::POSIX";

  # TODO define provider type automatically.
  $provider->require;

  Rex::Logger::debug("Get file provider: $provider");

  my $provider_o =
    $provider->new( type => "file", name => $name, config => { %args } );
  $provider_o->process;
  };

1;

=head1 NAME

Rex::Resource::file - Ensures the state of a file on the remote system.

=head1 DESCRIPTION

With the file() resource it is possible to manage files on the remote system.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
 };

=head2 run $command, %options

Supported options are:

  content           => $content
    sets the content of a file to the given value.
  source            => $local_source
    use the local file defined here to upload it to the remote system.

=cut
