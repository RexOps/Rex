#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::file::Provider::linux - File functions for linux systems.

=head1 DESCRIPTION

These are the parameters that are supported under linux systems. This is a base class for POSIX systems.

=head1 PARAMETER

=over 4

=item ensure

What state the resource should be ensured. 

Valid options:

=over 4

=item present

Creates the file if not present.

=item absent

Removes the file if present.

=back

=back

=cut

package Rex::Resource::file::Provider::linux;

use strict;
use warnings;

# VERSION

use Moose;
use MooseX::Aliases;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Rex::Helper::Path;
use Data::Dumper;

require Rex::Hook;
require File::Temp;

extends qw(Rex::Resource::file::Provider::base);
with qw(Rex::Resource::Role::Ensureable);

has '+ensure_options' =>
  ( default => sub { [qw/present absent file directory/] }, );

sub present {
  my ($self) = @_;

  my $file = $self->name;

  if ( $self->need_upload ) {
    if ( $self->is_file ) {
      $self->_create_file;
    }

    if ( $self->is_dir ) {
      my $not_recursive = $self->config->{not_recursive};

      if ($not_recursive) {
        $self->_create_directory;
      }
      else {
        $self->_create_directory_recursive;
      }
    }
  }

  my %stat_old = $self->fs->stat($file);
  my $message  = "";

  if ( defined $self->config->{mode}
    && $stat_old{mode} ne $self->config->{mode} )
  {
    $self->fs->chmod( $self->config->{mode}, $file );
    $message .=
      "\nChanged mode from " . $stat_old{mode} . " to " . $self->config->{mode};
  }

  if ( defined $self->config->{group} || defined $self->config->{owner} ) {

    my $user_o = Rex::User->create;
    my %owner  = $user_o->get_user_by_uid( $stat_old{uid} );
    my %group  = $user_o->get_group_by_gid( $stat_old{gid} );

    if ( defined $self->config->{group}
      && $group{name} ne $self->config->{group} )
    {
      $self->fs->chgrp( $self->config->{group}, $file );
      $message .=
          "\nChanged group from "
        . $group{name} . " to "
        . $self->config->{group};
    }

    if ( defined $self->config->{owner}
      && $owner{name} ne $self->config->{owner} )
    {
      $self->fs->chown( $self->config->{owner}, $file );
      $message .=
          "\nChanged owner from "
        . $owner{name} . " to "
        . $self->config->{owner};
    }
  }

  $self->_set_message($message);
  $self->_set_status(created);

  return 1;
}

# create aliases for ensure => "directory" and ensure => "file"
alias directory => "present";
alias file      => "present";

sub absent {
  my ($self) = @_;

  # we can also remove a file with rmdir method. so just use this one.
  $self->fs->rmdir( $self->name );

  $self->_set_status(removed);

  return 1;
}

sub _create_file {
  my ($self) = @_;

  # we upload the file at first to a temporary location.
  # then we can rename it in one atomic call.

  Rex::Logger::debug(
    "Resource::file::Provider::linux::_create_file: creating new file.");

  if ( defined $self->config->{source} ) {
    $self->fs->upload( $self->config->{source}, $self->tmp_file_name );
  }
  else {
    my $content = $self->config->{content} || "";

# we have not a local file to upload, so create a temporary file on local system
# to upload this via sftp. So we don't need to work with remote file handles.
    Rex::Logger::debug(
      "Resource::file::Provider::linux::_create_file: creating temp file with content:"
    );
    Rex::Logger::debug( $self->config->{content} );

    my ( $fh, $t_filename ) = File::Temp::tempfile();
    $fh->autoflush(1);
    print $fh $content;
    $fh->flush; # just to be sure...
    $self->fs->upload( $t_filename, $self->tmp_file_name );
    close $fh;  # this will also remove the temporary file on local system.
  }

  # check if we're running under sudo. If we're running under sudo
  # we need to chown the file to our logged in user
  # this is for sudo runs where the sudo user is not root.
  if (Rex::is_sudo) {
    my $current_options =
      Rex::get_current_connection_object()->get_current_sudo_options;
    Rex::get_current_connection_object()->push_sudo_options( {} );

    if ( exists $current_options->{user} ) {
      $self->fs->chown( "$current_options->{user}:", $self->tmp_file_name );
    }
  }

  $self->fs->rename( $self->tmp_file_name, resolv_path( $self->name ) );
  Rex::get_current_connection_object()->pop_sudo_options()
    if (Rex::is_sudo);
}

sub _create_directory {
  my ($self) = @_;

  my $file = $self->name;
  if ( !$self->fs->mkdir($file) ) {
    Rex::Logger::debug("Can't create directory $file");
    die("Can't create directory $file");
  }
}

sub _create_directory_recursive {
  my ($self) = @_;

  # TODO: Add Windows provider
  my @splitted_dir = map { "/$_"; } split( /\//, $self->name );
  unless ( $splitted_dir[0] eq "/" ) {
    $splitted_dir[0] = "." . $splitted_dir[0];
  }
  else {
    shift @splitted_dir;
  }

  my $str_part = "";
  for my $part (@splitted_dir) {
    $str_part .= "$part";

    if ( !$self->fs->is_dir($str_part) && !$self->fs->is_file($str_part) ) {
      if ( !$self->fs->mkdir($str_part) ) {
        Rex::Logger::debug( "Can't create directory " . $self->name );
        die( "Can't create directory " . $self->name );
      }

      $self->fs->chown( $self->config->{owner}, $str_part )
        if $self->config->{owner};
      $self->fs->chgrp( $self->config->{group}, $str_part )
        if $self->config->{group};
      $self->fs->chmod( $self->config->{mode}, $str_part )
        if $self->config->{mode};
    }
  }
}

1;
