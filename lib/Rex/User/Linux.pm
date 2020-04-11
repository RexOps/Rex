#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User::Linux;

use strict;
use warnings;

# VERSION

use Rex::Logger;
require Rex::Commands;
use Rex::Commands::MD5;
use Rex::Helper::Run;
use Rex::Helper::Encode;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Helper::Path;
use JSON::MaybeXS;

use Rex::User::Base;
use base qw(Rex::User::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub create_user {
  my ( $self, $user, $data ) = @_;

  my $cmd;

  my $uid = $self->get_uid($user);

  my $run_cmd = 0;
  my $should_create_home;

  # if any home creation intent has been defined,
  # don't follow the default home creation policy
  my $use_default_home_policy =
    (    defined $data->{'create_home'}
      || defined $data->{'create-home'}
      || defined $data->{'no_create_home'}
      || defined $data->{'no-create-home'} ) ? 0 : 1;

  if ( !$use_default_home_policy ) {
    if ( $data->{'create_home'} || $data->{'create-home'} ) {
      $should_create_home = 1;
    }
    elsif ( $data->{'no_create_home'} || $data->{'no-create-home'} ) {
      $should_create_home = 0;
    }
    elsif (
         ( exists $data->{'no_create_home'} && $data->{'no_create_home'} == 0 )
      || ( exists $data->{'no-create-home'} && $data->{'no-create-home'} == 0 )
      )
    {
      $should_create_home = 1;
    }
  }

  if ( !defined $uid ) {
    Rex::Logger::debug("User $user does not exists. Creating it now.");
    $cmd = "/usr/sbin/useradd ";

    if ( exists $data->{system} ) {
      $cmd .= " -r";
    }

    $run_cmd = 1;
  }
  else {
    # only the user should be there, no modifications.
    # so just return
    if ( !defined $data ) {
      return {
        changed => 0,
        uid     => $uid,
      };
    }

    Rex::Logger::debug("User $user already exists. Updating...");

    if ( exists $data->{uid} && $data->{uid} == $uid ) {
      delete $data->{uid};
    }

    $cmd = "/usr/sbin/usermod ";
  }

  if ( exists $data->{non_uniq} ) {
    $cmd .= " -o ";
    $run_cmd = 1;
  }

  if ( exists $data->{uid} ) {
    $cmd .= " --uid " . $data->{uid};
    $run_cmd = 1;
  }

  if ( exists $data->{home} ) {
    $run_cmd = 1;
    $cmd .= " -d " . $data->{home};

    # don't create home directory in useradd mode if it already exists
    $should_create_home = 0 if ( !defined $uid && is_dir( $data->{home} ) );
  }

  if ( !$use_default_home_policy ) {
    if ( !defined $uid ) { #useradd mode
      if ($should_create_home) {
        $cmd .= " -m ";
      }
      else {
        $cmd .= " -M ";
      }
    }
    else {                 #usermod mode
      $cmd .= " -m " if ( exists $data->{home} );
    }
  }

  if ( exists $data->{shell} ) {
    $run_cmd = 1;
    $cmd .= " --shell " . $data->{shell};
  }

  if ( exists $data->{comment} ) {
    $run_cmd = 1;
    $cmd .= " --comment '" . $data->{comment} . "'";
  }

  if ( exists $data->{expire} ) {
    $run_cmd = 1;
    $cmd .= " --expiredate '" . $data->{expire} . "'";
  }

  if ( exists $data->{groups} ) {
    $run_cmd = 1;
    my @groups    = @{ $data->{groups} };
    my $pri_group = shift @groups;

    $cmd .= " --gid $pri_group";

    if (@groups) {
      $cmd .= " --groups " . join( ",", @groups );
    }
  }

  my $old_pw_md5 = md5("/etc/passwd");
  my $old_sh_md5 = "";
  eval { $old_sh_md5 = md5("/etc/shadow"); };

  # only run the cmd if needed
  if ($run_cmd) {
    my $rnd_file = get_tmp_file;
    my $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write("rm \$0\n$cmd $user\nexit \$?\n");
    $fh->close;

    i_run "/bin/sh $rnd_file", fail_ok => 1;
    if ( $? == 0 ) {
      Rex::Logger::debug("User $user created/updated.");
    }
    else {
      Rex::Logger::info( "Error creating/updating user $user", "warn" );
      die("Error creating/updating user $user");
    }

  }

  if ( exists $data->{password} ) {
    my $rnd_file = get_tmp_file;
    my $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write( "rm \$0\n/bin/echo -e '"
        . $data->{password} . "\\n"
        . $data->{password}
        . "' | /usr/bin/passwd $user\nexit \$?\n" );
    $fh->close;

    Rex::Logger::debug("Changing password of $user.");
    i_run "/bin/sh $rnd_file", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error setting password for $user");
    }

  }

  if ( exists $data->{crypt_password} && $data->{crypt_password} ) {
    my $rnd_file = get_tmp_file;
    my $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write( "rm \$0\nusermod -p '"
        . $data->{crypt_password}
        . "' $user\nexit \$?\n" );
    $fh->close;

    Rex::Logger::debug("Setting encrypted password of $user");
    i_run "/bin/sh $rnd_file", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error setting password for $user");
    }
  }

  my $new_pw_md5 = md5("/etc/passwd");
  my $new_sh_md5 = "";
  eval { $new_sh_md5 = md5("/etc/shadow"); };

  if ( $new_pw_md5 eq $old_pw_md5 && $new_sh_md5 eq $old_sh_md5 ) {
    return {
      changed => 0,
      ret     => $self->get_uid($user),
    };
  }
  else {
    return {
      changed => 1,
      ret     => $self->get_uid($user),
      },
      ;
  }

}

sub rm_user {
  my ( $self, $user, $data ) = @_;

  Rex::Logger::debug("Removing user $user");

  my $cmd = "/usr/sbin/userdel";

  if ( exists $data->{delete_home} ) {
    $cmd .= " --remove";
  }

  if ( exists $data->{force} ) {
    $cmd .= " --force";
  }

  my $output = i_run $cmd . " " . $user, fail_ok => 1;
  if ( $? == 6 ) {
    Rex::Logger::info( "Cannot delete user $user (no such user)", "warn" );
  }
  elsif ( $? != 0 ) {
    die("Error deleting user $user ($output)");
  }

}

sub get_uid {
  my ( $self, $user ) = @_;

  my %data = $self->get_user($user);
  return $data{uid};
}

sub user_groups {
  my ( $self, $user ) = @_;

  Rex::Logger::debug("Getting group membership of $user");
  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  my $script   = q|
  unlink $0;
  $exe = "/usr/bin/groups";
  if(! -x $exe) {
    $exe = "/bin/groups";
  } print to_json([  map {chomp; $_ =~ s/^[^:]*:\s*(.*)\s*$/$1/; split / /, $_}  qx{$exe $ARGV[0]} ]);

  |;

  $fh->open( ">", $rnd_file );
  $fh->write($script);
  $fh->write( func_to_json() );
  $fh->close;

  my $data_str = i_run "perl $rnd_file $user", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting group list");
  }

  my $data = decode_json($data_str);

  my $wantarray = wantarray();

  if ( defined $wantarray && !$wantarray ) {

    # arrayref
    return $data;
  }

  return @{$data};
}

sub user_list {
  my $self = shift;

  Rex::Logger::debug("Getting user list");
  my $rnd_file = get_tmp_file;
  my $script   = q|
    unlink $0;
    print to_json([ map {chomp; $_ =~ s/^([^:]*):.*$/$1/; $_}  qx{/usr/bin/getent passwd} ]);
  |;
  my $fh = Rex::Interface::File->create;
  $fh->open( ">", $rnd_file );
  $fh->write($script);
  $fh->write( func_to_json() );
  $fh->close;

  my $data_str = i_run "perl $rnd_file", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting user list");
  }

  my $data = decode_json($data_str);

  return @$data;
}

sub get_user {
  my ( $self, $user ) = @_;

  Rex::Logger::debug("Getting information for $user");
  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  my $script   = q|
    unlink $0;
    print to_json([ getpwnam($ARGV[0]) ]);
  |;
  $fh->open( ">", $rnd_file );
  $fh->write($script);
  $fh->write( func_to_json() );
  $fh->close;

  my $data_str = i_run "perl $rnd_file $user", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting user information for $user");
  }

  my $data = decode_json($data_str);

  return (
    name     => $data->[0],
    password => $data->[1],
    uid      => $data->[2],
    gid      => $data->[3],
    comment  => $data->[5],
    home     => $data->[7],
    shell    => $data->[8],
    expire   => exists $data->[9] ? $data->[9] : 0,
  );
}

sub lock_password {
  my ( $self, $user ) = @_;

  # Is the password already locked?
  my $result = i_run "passwd --status $user", fail_ok => 1;

  die "Unexpected result from passwd: $result"
    unless $result =~ /^$user\s+(L|NP|P)\s+/;

  if ( $1 eq 'L' ) {

    # Already locked
    return { changed => 0 };
  }
  else {
    my $ret = i_run "passwd --lock $user", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error locking account $user: $ret");
    }
    return {
      changed => 1,
      ret     => $ret,
    };
  }
}

sub unlock_password {
  my ( $self, $user ) = @_;

  # Is the password already unlocked?
  my $result = i_run "passwd --status $user", fail_ok => 1;

  die "Unexpected result from passwd: $result"
    unless $result =~ /^$user\s+(L|NP|P)\s+/;

  if ( $1 eq 'P' ) {

    # Already unlocked
    return { changed => 0 };
  }
  else {
    # Capture error string on failure (eg. account has no password)
    my ( $ret, $err ) = i_run "passwd --unlock $user", sub { @_ }, fail_ok => 1;
    if ( $? != 0 ) {
      die("Error unlocking account $user: $err");
    }
    return {
      changed => 1,
      ret     => $ret,
    };
  }
}

sub create_group {
  my ( $self, $group, $data ) = @_;

  my $cmd;

  my $gid = $self->get_gid($group);

  if ( !defined $gid ) {
    Rex::Logger::debug("Creating new group $group");

    $cmd = "/usr/sbin/groupadd ";
  }
  elsif ( exists $data->{gid} && $data->{gid} == $gid ) {
    if ( Rex::Config->get_do_reporting ) {
      return {
        changed => 0,
        ret     => $gid,
      };
    }
    return $gid;
  }
  else {
    if ( !defined $data ) {
      if ( Rex::Config->get_do_reporting ) {
        return {
          changed => 0,
          ret     => $gid,
        };
      }

      return $gid;
    }
    Rex::Logger::debug("Group $group already exists. Updating...");
    $cmd = "/usr/sbin/groupmod ";
  }

  if ( exists $data->{gid} ) {
    $cmd .= " -g " . $data->{gid};
    $gid = undef;
  }

  i_run $cmd . " " . $group, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error creating/modifying group $group");
  }

  if ( defined $gid ) {
    return $gid;
  }

  return $self->get_gid($group);
}

sub get_gid {
  my ( $self, $group ) = @_;

  my %data = $self->get_group($group);
  return $data{gid};
}

sub get_group {
  my ( $self, $group ) = @_;

  Rex::Logger::debug("Getting information for $group");
  my @data =
    split(
    " ",
    ""
      . i_run(
      "perl -le 'print join(\" \", getgrnam(\$ARGV[0]));' '$group'",
      fail_ok => 1
      ),
    4
    );
  if ( $? != 0 ) {
    die("Error getting group information");
  }

  return (
    name     => $data[0],
    password => $data[1],
    gid      => $data[2],
    members  => $data[3],
  );
}

sub rm_group {
  my ( $self, $group ) = @_;

  i_run "/usr/sbin/groupdel $group", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error deleting group $group");
  }
}

1;
