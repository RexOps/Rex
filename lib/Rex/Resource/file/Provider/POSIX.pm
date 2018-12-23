#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::file::Provider::POSIX - POSIX compatible file provider

=head1 DESCRIPTION

=head1 PARAMETER

=cut

package Rex::Resource::file::Provider::POSIX;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

require Rex::Commands::MD5;

extends qw(Rex::Resource::Provider);
with qw(Rex::Resource::file::Role);

sub test {
  my ($self) = @_;

  my $fs = Rex::Interface::Fs->create;
  
  if($self->config->{ensure} eq "absent") {
    if($fs->is_file($self->config->{path})) {
      return 1;
    }
    elsif($fs->is_dir($self->config->{path})) {
      return 1;
    }

    return 0;
  }

  if($self->config->{ensure} eq "directory") {
    if($fs->is_dir($self->config->{path})) {
      return 1;
    }
    return 0;
  }

  my $remote_md5 = eval { Rex::Commands::MD5::md5($self->config->{path}); } // "";
  my $local_md5;

  if($self->config->{content}) {
    $local_md5 = md5_hex($self->config->{content});
  }

  if($remote_md5 eq $local_md5) {
    # nothing todo
    return 1;
  }

  # we have to do something
  return 0;
}

sub present {
  my ($self) = @_;
  my $fs   = Rex::Interface::Fs->create;

  my $remote_md5 = eval { Rex::Commands::MD5::md5($self->config->{path}); } // "";
  my $local_md5;

  if($self->config->{content}) {
    $local_md5 = md5_hex($self->config->{content});
  }

  if($remote_md5 eq $local_md5) {
    # TODO: also check owner, group and mode
    return {
      value => "",
      exit_code => 0,
      changed => 0,
      status => state_good,
    };
  }

  if($self->config->{content}) {
    my %opts = ();
    $opts{owner} = $self->config->{owner} if($self->config->{owner});
    $opts{group} = $self->config->{group} if($self->config->{group});
    $opts{mode}  = $self->config->{mode}  if($self->config->{mode});

    my $exit_code = 0;
    eval {
      $fs->file_put_contents($self->config->{path}, $self->config->{content}, %opts );
      1;
    } or do {
      $exit_code = 1;
    };

    return {
      value => "",
      exit_code => $exit_code,
      changed => 1,
      status => ($exit_code == 0 ? state_changed : state_failed),
    };
  }
}

sub absent {
  my ($self) = @_;

  my $fs   = Rex::Interface::Fs->create;
  if($fs->is_file($self->config->{path})) {
    my $exit_code = 0;

    eval {
      $fs->unlink($self->config->{path});
      1;
    } or do {
      $exit_code = 1;
    };

    return {
      value => "",
      exit_code => $exit_code,
      changed => 0,
      status => ($exit_code == 0 ? state_changed : state_failed),
    };
  }
  elsif($fs->is_dir($self->config->{path})) {
    my $exit_code = 0;

    eval {
      $fs->rmdir($self->config->{path});
      1;
    } or do {
      $exit_code = 1;
    };

    return {
      value => "",
      exit_code => $exit_code,
      changed => 0,
      status => ($exit_code == 0 ? state_changed : state_failed),
    };
  }
  else {
    return {
      value => "",
      exit_code => 0,
      changed => 0,
      status => state_good,
    };
  }
}

sub directory {
  my ($self) = @_;

  my $exit_code = 0;

  eval {
    my $fs = Rex::Interface::Fs->create;
    $fs->mkdir_p($self->config->{path});

    $fs->chown($self->config->{owner}, $self->config->{path}) if($self->config->{owner});
    $fs->chgrp($self->config->{group}, $self->config->{path}) if($self->config->{group});
    $fs->chmod($self->config->{mode}, $self->config->{path})  if($self->config->{mode});
    1;
  } or do {
    $exit_code = 1;
  };

  return {
    value => "",
    exit_code => $exit_code,
    changed => 1,
    status => ($exit_code == 0 ? state_changed : state_failed),
  };
}

1;

