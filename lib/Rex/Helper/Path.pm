#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::Path;

use strict;
use warnings;

# VERSION

use Rex::Helper::File::Spec;
use File::Basename qw(basename dirname);
require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);
use Cwd 'realpath';

require Rex;
use Rex::Commands;
require Rex::Config;

use Rex::Interface::Exec;
use Rex::Interface::Fs;

@EXPORT = qw(get_file_path get_tmp_file resolv_path parse_path resolve_symlink);

set "path_map", {};

#
# CALL: get_file_path("foo.txt", caller());
# RETURNS: module file
#
sub get_file_path {
  my ( $file_name, $caller_package, $caller_file ) = @_;

  $file_name = resolv_path($file_name);

  my $ends_with_slash = 0;
  if ( $file_name =~ m/\/$/ ) {
    $ends_with_slash = 1;
  }

  my $has_wildcard = 0;
  my $base_name    = basename($file_name);

  if ( $base_name =~ qr{\*} ) {
    $has_wildcard = 1;
    $file_name    = dirname($file_name);
  }

  my $fix_path = sub {
    my ($path) = @_;
    $path =~ s:^\./::;

    if ($has_wildcard) {
      $path = Rex::Helper::File::Spec->catfile( $path, $base_name );
    }

    if ($ends_with_slash) {
      if ( $path !~ m/\/$/ ) {
        return "$path/";
      }
    }

    return $path;
  };

  if ( !$caller_package ) {
    ( $caller_package, $caller_file ) = caller();
  }

  # check if a file in $BASE overwrites the module file
  # first get the absolute path to the rexfile

  $::rexfile ||= $0;

  if ( $caller_file =~ m|^/loader/[^/]+/__Rexfile__.pm$| ) {
    $caller_file = $::rexfile;
  }

  my @path_parts;
  if ( $^O =~ m/^MSWin/ && !Rex::is_ssh() ) {
    @path_parts = split( /\//, $::rexfile );
  }
  else {
    @path_parts = split( /\//, realpath($::rexfile) );
  }
  pop @path_parts;

  my $real_path = join( '/', @path_parts );

  my $map_setting = get("path_map");

  my %path_map = (
    map { ( ( substr( $_, -1 ) eq '/' ) ? $_ : "$_/" ) => $map_setting->{$_} }
      keys %$map_setting
  );

  foreach my $prefix (
    sort { length($b) <=> length($a) }
    grep { $file_name =~ m/^$_/ } keys %path_map
    )
  {
    foreach my $pattern ( @{ $path_map{$prefix} } ) {
      my $expansion =
        Rex::Helper::File::Spec->catfile( parse_path($pattern),
        substr( $file_name, length($prefix) ) );

      if ( -e $expansion ) {
        return $fix_path->($expansion);
      }

      $expansion = Rex::Helper::File::Spec->catfile( $real_path, $expansion );
      if ( -e $expansion ) {
        return $fix_path->($expansion);
      }
    }
  }

  if ( -e $file_name ) {
    return $fix_path->($file_name);
  }

  my $cat_file_name =
    Rex::Helper::File::Spec->catfile( $real_path, $file_name );
  if ( -e $cat_file_name ) {
    return $fix_path->($cat_file_name);
  }

  # walk down the wire to find the file...
  my ($old_caller_file) = $caller_file;
  my $i = 0;
  while ( $caller_package && $i <= 50 ) {
    ( $caller_package, $caller_file ) = caller($i);
    if ( !$caller_package ) {
      last;
    }

    my $module_path = Rex::get_module_path($caller_package);
    $cat_file_name =
      Rex::Helper::File::Spec->catfile( $module_path, $file_name );
    if ( -e $cat_file_name ) {
      return $fix_path->($cat_file_name);
    }

    $i++;
  }

  $file_name =
    Rex::Helper::File::Spec->catfile( dirname($old_caller_file), $file_name );

  return $fix_path->($file_name);
}

sub get_tmp_file {
  return Rex::Helper::File::Spec->join( Rex::Config->get_tmp_dir(),
    Rex::Commands::get_random( 12, 'a' .. 'z' ) . '.tmp' );
}

sub resolv_path {
  my ( $path, $local ) = @_;

  if ( $path !~ m/^~/ ) {

    # path starts not with ~ so we don't need to expand $HOME.
    # just return it.
    return $path;
  }

  my $home_path;
  require Rex::User;
  my $user_o = Rex::User->get;

  if ($local) {
    if ( $^O =~ m/^MSWin/ ) {

      # windows path:
      $home_path = $ENV{'USERPROFILE'};
    }
    else {
      if ( $path =~ m/^~([a-zA-Z0-9_][^\/]+)\// ) {
        my $user_name = $1;
        my %user_info = $user_o->get_user($user_name);
        $home_path = $user_info{home};
        $path =~ s/^~$user_name/$home_path/;
      }
      else {
        $home_path = $ENV{'HOME'};
        $path =~ s/^~/$home_path/;
      }
    }
  }
  else {
    if ( $path =~ m/^~([a-zA-Z0-9_][^\/]+)\// ) {
      my $user_name = $1;
      my %user_info = $user_o->get_user($user_name);
      $home_path = $user_info{home};
      $path =~ s/^~$user_name/$home_path/;
    }
    else {
      my $exec        = Rex::Interface::Exec->create;
      my $remote_home = $exec->exec("echo \$HOME");
      $remote_home =~ s/[\r\n]//gms;
      $home_path = $remote_home;
      $path =~ s/^~/$home_path/;
    }
  }

  return $path;
}

sub parse_path {
  my ($path) = @_;
  my %hw;

  require Rex::Commands::Gather;

  $hw{server}      = Rex::Commands::connection()->server;
  $hw{environment} = Rex::Commands::environment();

  $path =~ s/\{(server|environment)\}/$hw{$1}/gms;

  if ( $path =~ m/\{([^\}]+)\}/ ) {

    # if there are still some variables to replace, we need some information of
    # the system.
    %hw = Rex::Commands::Gather::get_system_information();
    $path =~ s/\{([^\}]+)\}/$hw{$1}/gms;
  }

  return $path;
}

sub resolve_symlink {
  my $path = shift;
  my $fs   = Rex::Interface::Fs::create();
  my $resolution;

  if ( $fs->is_symlink($path) ) {
    while ( my $link = $fs->readlink($path) ) {
      if ( $link !~ m/^\// ) {
        $path = dirname($path) . "/" . $link;
      }
      else {
        $path = $link;
      }
      $link = $fs->readlink($link);
    }
    $resolution = $path;
  }

  return $resolution;
}

1;
