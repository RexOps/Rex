#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::file::Provider::base;

use strict;
use warnings;

# VERSION

use Moose;
use Data::Dumper;
use List::MoreUtils qw/any/;

use Rex::Helper::Run;
use Rex::Helper::Path;
require Digest::MD5;

extends qw(Rex::Resource::Provider);

has is_file => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    any { $self->config->{ensure} eq $_ } qw/present file/;
  },
);

has is_dir => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    any { $self->config->{ensure} eq $_ } qw/directory/;
  },
);

has tmp_file_name => (
  is      => 'ro',
  isa     => 'Str | Undef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;

    my @splitted_file = split( /[\/\\]/, $self->name );
    my $file_name     = ".rex.tmp." . pop(@splitted_file);
    my $tmp_file_name = (
      $#splitted_file != -1
      ? ( join( "/", @splitted_file ) . "/" . $file_name )
      : $file_name
    );

    return $tmp_file_name;
  },
);

has need_upload => (
  is      => 'ro',
  isa     => 'Bool',
  writer  => '_set_upload',
  default => sub { 1 },
);

sub test {
  my ($self) = @_;

  my $file = $self->name;

  my $is_file   = $self->is_file;
  my $is_dir    = $self->is_dir;
  my $is_absent = any { $self->config->{ensure} eq $_ } qw/absent/;
  my $chksum_ok = 1;

  if ( $is_file && $self->fs->is_file($file) ) {
    if ( $self->config->{source} || $self->config->{content} ) {

      # checksum compare
      my $local_fs      = Rex::Interface::Fs->create("Local");
      my $remote_chksum = $self->fs->chksum($file);
      my $local_chksum =
          $self->config->{source}
        ? $local_fs->chksum( $self->config->{source} )
        : Digest::MD5::md5_hex( $self->config->{content} || "" );
      $chksum_ok = $remote_chksum eq $local_chksum;
    }

    if ($chksum_ok) {
      $self->_set_upload(0);
    }

    if ( $chksum_ok && $self->_stat_ok($file) ) {
      return 1;
    }
    else {
      return 0;
    }
  }
  elsif ( $is_dir && $self->fs->is_dir($file) ) {
    if ( $self->_stat_ok($file) ) {
      return 1;
    }
    else {
      return 0;
    }
  }
  elsif ( $is_absent
    && !( $self->fs->is_file($file) || $self->fs->is_dir($file) ) )
  {
    return 1;
  }

  # we have to do something
  return 0;
}

sub _stat_ok {
  my ( $self, $file ) = @_;

  my %stat = $self->fs->stat($file);

  my $user_o = Rex::User->create;
  my %owner  = $user_o->get_user_by_uid( $stat{uid} );
  my %group  = $user_o->get_group_by_gid( $stat{gid} );

  my $stat_chown_ok =
    $self->config->{owner} ? $owner{name} eq $self->config->{owner} : 1;
  my $stat_chgrp_ok =
    $self->config->{group} ? $group{name} eq $self->config->{group} : 1;
  my $stat_chmod_ok =
    $self->config->{mode} ? $stat{mode} eq $self->config->{mode} : 1;

  if ( $stat_chgrp_ok && $stat_chmod_ok && $stat_chown_ok ) {
    return 1;
  }
  else {
    return 0;
  }
}

1;
