#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
  
package Rex::Helper::Path;

use strict;
use warnings;

use File::Basename qw(dirname);
require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);
use Cwd 'realpath';

require Rex::Commands;
require Rex::Config;
require Rex;

use Rex::Interface::Exec;

@EXPORT = qw(get_file_path get_tmp_file resolv_path);

#
# CALL: get_file_path("foo.txt", caller());
# RETURNS: module file
#
sub get_file_path {
  my ($file_name, $caller_package, $caller_file) = @_;

  $file_name = resolv_path($file_name);


  if(! $caller_package) {
    ($caller_package, $caller_file) = caller();
  }

  # check if a file in $BASE overwrites the module file
  # first get the absoltue path to the rexfile

  $::rexfile ||= $0;

  my @path_parts;
  if($^O =~ m/^MSWin/ && ! Rex::is_ssh()) {
    @path_parts = split(/\//, $::rexfile);
  }
  else {
    @path_parts = split(/\//, realpath($::rexfile));
  }
  pop @path_parts;

  my $real_path = join('/', @path_parts);

  if(-e $file_name) {
    return $file_name;
  }

  if(-e $real_path . '/' . $file_name) {
    return $real_path . '/' . $file_name;
  }

  # walk down the wire to find the file...
  my ($old_caller_file) = $caller_file;
  my $i = 0;
  while($caller_package && $i <= 50) {
    ($caller_package, $caller_file) = caller($i);
    if(! $caller_package) {
      last;
    }

    my $module_path = Rex::get_module_path($caller_package);
    if(-e "$module_path/$file_name") {
      $file_name = "$module_path/$file_name";
      return $file_name;
    }

    $i++;
  }

  $file_name = dirname($old_caller_file) . "/" . $file_name;

  return $file_name;
}

sub get_tmp_file {
  my $rnd_file;

  if(Rex::is_ssh()) {
    $rnd_file = Rex::Config->get_tmp_dir . "/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp";
  }
  elsif($^O =~ m/^MSWin/) {
    my $tmp_dir = Rex::Config->get_tmp_dir;
    if($tmp_dir eq "/tmp") {
      $tmp_dir = $ENV{TMP};
    }

    $rnd_file = $tmp_dir . "/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp"
  }
  else {
    $rnd_file = Rex::Config->get_tmp_dir . "/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp";
  }

  return $rnd_file;
}

sub resolv_path {
  my ($path, $local) = @_;

  if($path !~ m/^~/) {
    # path starts not with ~ so we don't need to expand $HOME.
    # just return it.
    return $path;
  }

  my $home_path;
  require Rex::User;
  my $user_o = Rex::User->get;

  if($local) {
    if($^O =~ m/^MSWin/) {
      # windows path:
      $home_path = $ENV{'USERPROFILE'};
    }
    else {
      if($path =~ m/^~([a-zA-Z0-9_][^\/]+)\//) {
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
    if($path =~ m/^~([a-zA-Z0-9_][^\/]+)\//) {
      my $user_name = $1;
      my %user_info = $user_o->get_user($user_name);
      $home_path = $user_info{home};
      $path =~ s/^~$user_name/$home_path/;
    }
    else {
      my $exec = Rex::Interface::Exec->create;
      my $remote_home = $exec->exec("echo \$HOME");
      $remote_home =~ s/[\r\n]//gms;
      $home_path = $remote_home;
      $path =~ s/^~/$home_path/;
    }
  }

  return $path;
}

1;
