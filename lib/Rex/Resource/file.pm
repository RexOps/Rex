#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::file - File management

=head1 DESCRIPTION

With this module it is possible to manage files.

=head1 SYNOPSIS

 task "setup", sub {
   file "/remote/file",
     ensure  => "present",
     content => "this is some text",
     owner   => "root",
     group   => "root",
     mode    => "0644",
     on_change => sub { print "File was changed!\n"; };

   file ["/remote/file1", "/remote/file2", "/remote/file3"],
     ensure  => "present",
     owner   => "root",
     group   => "root",
     mode    => "0644";

   file "/remote/file",
     ensure  => "present",
     content => "this is some text",
     owner   => "root",
     group   => "root",
     mode    => "0644",
     no_overwrite => TRUE;

   file "/remote/file",
     ensure  => "absent";

   file "/remote/directory",
     ensure  => "directory",
     owner   => "root",
     group   => "root",
     mode    => "0644";

   file "/remote/directory",
     ensure  => "directory",
     owner   => "root",
     group   => "root",
     mode    => "0644",
     not_recursive => TRUE;
 };

=head1 PARAMETER

=over 4

=item ensure

Valid options:

=over 4

=item present

Make sure that the file exists. It will also update the content if the file if needed.

=item file

An alias for I<present>.

=item directory

Make sure that the given directory exists.

=item absent

Make sure that the given file (or directory) is removed.

=back

=item mode

The I<chmod> of the file. This parameter should be provided as an octal string. For example: I<"0644">. 
The default is to use the system specific umask.

=item owner

The I<owner> for the file or directory. The default is the user rex used to connect to the server.

=item group

The I<group> for the file. The default is the user's primary group rex used to connect to the server.

=item source

If provided, it will use the given local file and upload it to the location specified in the resource name.

=item content

If provided, it will use the given string for the content of the remote file.

=item no_overwrite

If I<TRUE> rex will not override a file if it already exists. Default I<FALSE>.

=item not_recursive

If I<TRUE> rex will not create a directory recursively. Default I<FALSE>.

=back

=cut

package Rex::Resource::file;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Rex::Helper::Path;

use Carp;

resource "file", { export => 1 }, sub {
  my $file_name = resolv_path( resource_name() );

  my $file_config = {
    ensure        => param_lookup( "ensure",        "present" ),
    name          => $file_name,
    mode          => param_lookup( "mode",          undef ),
    owner         => param_lookup( "owner",         undef ),
    group         => param_lookup( "group",         undef ),
    source        => param_lookup( "source",        undef ),
    content       => param_lookup( "content",       undef ),
    no_overwrite  => param_lookup( "no_overwrite",  undef ),
    not_recursive => param_lookup( "not_recursive", 0 ),
  };

  my $provider =
    param_lookup( "provider",
    get_resource_provider( kernelname(), operating_system() ) );

  Rex::Logger::debug("Get file provider: $provider");

  if ( defined $file_config->{source} ) {
    $file_config->{source} =
      get_file_path( resolv_path( $file_config->{source} ), caller() );

    if ( Rex::Config->get_environment
      && -f $file_config->{source} . "." . Rex::Config->get_environment )
    {
      $file_config->{source} =
        $file_config->{source} . "." . Rex::Config->get_environment;
    }
  }

  return ( $provider, $file_config );
};

1;
