#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::File - Transparent File Manipulation

=head1 DESCRIPTION

With this module you can manipulate files.

=head1 SYNOPSIS

 task "read_passwd", "server01", sub {
   my $fh = file_read "/etc/passwd";
   for my $line ($fh->read_all) {
     print $line;
   }
   $fh->close;
 };
 
 task "read_passwd2", "server01", sub {
   say cat "/etc/passwd";
 };


 task "write_passwd", "server01", sub {
   my $fh = file_write "/etc/passwd";
   $fh->write("root:*:0:0:root user:/root:/bin/sh\n");
   $fh->close;
 };
 
 delete_lines_matching "/var/log/auth.log", matching => "root";
 delete_lines_matching "/var/log/auth.log", matching => qr{Failed};
 delete_lines_matching "/var/log/auth.log",
                matching => "root", qr{Failed}, "nobody";
 
 file "/path/on/the/remote/machine",
   source => "/path/on/local/machine";
 
 file "/path/on/the/remote/machine",
   content => "foo bar";
 
 file "/path/on/the/remote/machine",
   source => "/path/on/local/machine",
   owner  => "root",
   group  => "root",
   mode  => 400,
   on_change => sub { say shift, " was changed."; },
   on_no_change => sub { say shift, " wasn't changed."; };


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::File;

use strict;
use warnings;
use Fcntl;

# VERSION

require Rex::Exporter;
use Data::Dumper;
use Rex::Config;
use Rex::FS::File;
use Rex::Commands::Upload;
use Rex::Commands::MD5;
use Rex::File::Parser::Data;
use Rex::Helper::File::Spec;
use Rex::Helper::System;
use Rex::Helper::Path;
use Rex::Hook;
use Carp;

use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;
require Rex::CMDB;

use File::Basename qw(dirname basename);

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(file_write file_read file_append
  cat sed
  delete_lines_matching append_if_no_such_line delete_lines_according_to
  file template append_or_amend_line
  extract);

use vars qw(%file_handles);

=head2 template($file, @params)

Parse a template and return the content.

=head3 Embedded templates

Use C<__DATA__> to embed templates at the end of the file. Prefix embedded template names with C<@>. If embedding multiple templates, mark their end with C<@end>.

=head4 Single template

 my $content = template( '@hello', name => 'world' ); # Hello, world!
 __DATA__
 @hello
 Hello, <%= $name -%>!

=head4 Multiple templates

Use C<@end> to separate multiple templates inside C<__DATA__>.

 my $content     = template( '@hello', name => 'world' ); # Hello, world!
 my $alternative = template( '@hi',    name => 'world' ); # Hi, world!

 __DATA__
 @hello
 Hello, <%= $name -%>!
 @end

 @hi
 Hi, <%= $name -%>!
 @end

=head3 File templates

 my $content = template("/files/templates/vhosts.tpl",
               name      => "test.lan",
               webmaster => 'webmaster@test.lan');

The file name specified is subject to "path_map" processing as documented
under the file() function to resolve to a physical file name.

In addition to the "path_map" processing, if the B<-E> command line switch
is used to specify an environment name, existence of a file ending with
'.<env>' is checked and has precedence over the file without one, if it
exists. E.g. if rex is started as:

 $ rex -E prod task1

then in task1 defined as:

 task "task1", sub {
    say template("files/etc/ntpd.conf");
 };

will print the content of 'files/etc/ntpd.conf.prod' if it exists.

Note: the appended environment mechanism is always applied, after
the 'path_map' mechanism, if that is configured.

=cut

sub template {
  my ( $file, @params ) = @_;
  my $param;

  if ( ref $params[0] eq "HASH" ) {
    $param = $params[0];
  }
  else {
    $param = {@params};
  }

  if ( !exists $param->{server} ) {
    $param->{server} = Rex::Commands::connection()->server;
  }

  my $content;
  if ( ref $file && ref $file eq 'SCALAR' ) {
    $content = ${$file};
  }
  else {
    $file = resolv_path($file);

    unless ( $file =~ m/^\// || $file =~ m/^\@/ ) {

      # path is relative and no template
      Rex::Logger::debug("Relativ path $file");

      $file = Rex::Helper::Path::get_file_path( $file, caller() );

      Rex::Logger::debug("New filename: $file");
    }

    # if there is a file called filename.environment then use this file
    # ex:
    # $content = template("files/hosts.tpl");
    #
    # rex -E live ...
    # will first look if files/hosts.tpl.live is available, if not it will
    # use files/hosts.tpl
    if ( -f "$file." . Rex::Config->get_environment ) {
      $file = "$file." . Rex::Config->get_environment;
    }

    if ( -f $file ) {
      $content = eval { local ( @ARGV, $/ ) = ($file); <>; };
    }
    elsif ( $file =~ m/^\@/ ) {
      my @caller = caller(0);

      my $file_path = Rex::get_module_path( $caller[0] );

      if ( !-f $file_path ) {
        my ($mod_name) = ( $caller[0] =~ m/^.*::(.*?)$/ );
        if ( $mod_name && -f "$file_path/$mod_name.pm" ) {
          $file_path = "$file_path/$mod_name.pm";
        }
        elsif ( -f "$file_path/__module__.pm" ) {
          $file_path = "$file_path/__module__.pm";
        }
        elsif ( -f "$file_path/Module.pm" ) {
          $file_path = "$file_path/Module.pm";
        }
        elsif ( -f $caller[1] ) {
          $file_path = $caller[1];
        }
        elsif ( $caller[1] =~ m|^/loader/[^/]+/__Rexfile__.pm$| ) {
          $file_path = $INC{"__Rexfile__.pm"};
        }
      }

      my $file_content = eval { local ( @ARGV, $/ ) = ($file_path); <>; };
      my ($data) = ( $file_content =~ m/.*__DATA__(.*)/ms );
      my $fp = Rex::File::Parser::Data->new( data => [ split( /\n/, $data ) ] );
      my $snippet_to_read = substr( $file, 1 );
      $content = $fp->read($snippet_to_read);
    }
    else {
      die("$file not found");
    }
  }

  my %template_vars;
  if ( !exists $param->{__no_sys_info__} ) {
    %template_vars = _get_std_template_vars($param);
  }
  else {
    delete $param->{__no_sys_info__};
    %template_vars = %{$param};
  }

  # configuration variables
  my $config_values = Rex::Config->get_all;
  for my $key ( keys %{$config_values} ) {
    if ( !exists $template_vars{$key} ) {
      $template_vars{$key} = $config_values->{$key};
    }
  }

  if ( Rex::CMDB::cmdb_active() && Rex::Config->get_register_cmdb_template ) {
    my $data = Rex::CMDB::cmdb();
    for my $key ( keys %{ $data->{value} } ) {
      if ( !exists $template_vars{$key} ) {
        $template_vars{$key} = $data->{value}->{$key};
      }
    }
  }

  return Rex::Config->get_template_function()->( $content, \%template_vars );
}

sub _get_std_template_vars {
  my ($param) = @_;

  my %merge1 = %{ $param || {} };
  my %merge2;

  if ( Rex::get_cache()->valid("system_information_info") ) {
    %merge2 = %{ Rex::get_cache()->get("system_information_info") };
  }
  else {
    %merge2 = Rex::Helper::System::info();
    Rex::get_cache()->set( "system_information_info", \%merge2 );
  }

  my %template_vars = ( %merge1, %merge2 );

  return %template_vars;
}

=head2 file($file_name, %options)

This function is the successor of I<install file>. Please use this function to upload files to your server.

 task "prepare", "server1", "server2", sub {
   file "/file/on/remote/machine",
     source => "/file/on/local/machine";
 
   file "/etc/hosts",
     content => template("templates/etc/hosts.tpl"),
     owner  => "user",
     group  => "group",
     mode   => 700,
     on_change => sub { say "Something was changed." },
     on_no_change => sub { say "Nothing has changed." };
 
   file "/etc/motd",
     content => `fortune`;
 
   file "/etc/named.conf",
     content    => template("templates/etc/named.conf.tpl"),
     no_overwrite => TRUE;  # this file will not be overwritten if already exists.
 
   file "/etc/httpd/conf/httpd.conf",
     source => "/files/etc/httpd/conf/httpd.conf",
     on_change => sub { service httpd => "restart"; };
 
   file "/etc/named.d",
     ensure => "directory",  # this will create a directory
     owner  => "root",
     group  => "root";
 
   file "/etc/motd",
     ensure => "absent";   # this will remove the file or directory
 
 };

The first parameter is either a string or an array reference. In the latter case the
function is called for all strings in the array. Therefore, the following constructs 
are equivalent:

  file '/tmp/test1', ensure => 'directory';
  file '/tmp/test2', ensure => 'directory';

  file [ qw( /tmp/test1 /tmp/test2 ) ], ensure => 'directory'; # use array ref

  file [ glob('/tmp/test{1,2}') ], ensure => 'directory'; # explicit glob call for array contents

Use the glob carefully as B<it can leak local filesystem information> (e.g. when using wildcards).

The I<source> is subject to a path resolution algorithm. This algorithm
can be configured using the I<set> function to set the value of the
I<path_map> variable to a hash containing path prefixes as its keys.
The associated values are arrays listing the prefix replacements in order
of (decreasing) priority.

  set "path_map", {
    "files/" => [ "files/{environment}/{hostname}/_root_/",
                  "files/{environment}/_root_/" ]
  };

With this configuration, the file "files/etc/ntpd.conf" will be probed for
in the following locations:

 - files/{environment}/{hostname}/_root_/etc/ntpd.conf
 - files/{environment}/_root_/etc/ntpd.conf
 - files/etc/ntpd.conf

Furthermore, if a path prefix matches multiple prefix entries in 'path_map',
e.g. "files/etc/ntpd.conf" matching both "files/" and "files/etc/", the
longer matching prefix(es) have precedence over shorter ones. Note that
keys without a trailing slash (i.e. "files/etc") will be treated as having
a trailing slash when matching the prefix ("files/etc/"). 

If no file is found using the above procedure and I<source> is relative,
it will search from the location of your I<Rexfile> or the I<.pm> file if
you use Perl packages.

All the possible variables ('{environment}', '{hostname}', ...) are documented
in the CMDB YAML documentation.

=head3 Hooks

This function supports the following L<hooks|Rex::Hook>:

=over 4

=item before

This gets executed before anything is done. All original parameters are passed to it, including the applied defaults (C<ensure => 'present', resolved path for C<source>).

The return value of this hook overwrites the original parameters of the function call.

=item before_change

This gets executed right before the new file is written. All original parameters are passed to it, including the applied defaults (C<ensure => 'present', resolved path for C<source>).

Only called when the C<content> parameter is used. For the C<source> parameter, the L<upload|Rex::Commands::Upload#upload> hooks are used.

=item after_change

This gets executed right after the file is written. All original parameters, including the applied defaults (C<ensure => 'present', resolved path for C<source>), and any returned results are passed to it.

Only called when the C<content> parameter is used. For the C<source> parameter, the L<upload|Rex::Commands::Upload#upload> hooks are used.

=item after

This gets executed right before the C<file()> function returns. All original parameters, including the applied defaults (C<ensure => 'present', resolved path for C<source>), and any returned results are passed to it.

=back

=cut

sub file {
  my ( $file, @options ) = @_;

  if ( ref $file eq "ARRAY" ) {
    my @ret;

    # $file is an array, so iterate over these files
    for my $f ( @{$file} ) {
      push( @ret, file( $f, @options ) );
    }

    return \@ret;
  }

  my $option = {@options};

  $file = resolv_path($file);

  my ($is_directory);
  if ( exists $option->{ensure} && $option->{ensure} eq "directory" ) {
    $is_directory = 1;
  }

  if ( exists $option->{source} && !$is_directory ) {
    $option->{source} = resolv_path( $option->{source} );
  }

  # default: ensure = present
  $option->{ensure} ||= "present";

  my $fs = Rex::Interface::Fs->create;

  if ( $option->{ensure} ne 'absent' && $fs->is_symlink($file) ) {
    my $original_file = $file;
    $file = resolve_symlink($file);
    Rex::Logger::info(
      "$original_file is a symlink, operating on $file instead", 'warn' );
  }

  #### check and run before hook
  eval {
    my @new_args = Rex::Hook::run_hook( file => "before", $file, %{$option} );
    if (@new_args) {
      ( $file, @options ) = @new_args;
      $option = {@options};
    }
    1;
  } or do {
    die("Before hook failed. Cancelling file() action: $@");
  };
  ##############################

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "file", name => $file );

  my $need_md5     = ( $option->{"on_change"} && !$is_directory ? 1 : 0 );
  my $on_change    = $option->{"on_change"}    || sub { };
  my $on_no_change = $option->{"on_no_change"} || sub { };

  my $__ret = { changed => 0 };

  my ( $new_md5, $old_md5 );

  if ( exists $option->{no_overwrite}
    && $option->{no_overwrite}
    && $fs->is_file($file) )
  {
    Rex::Logger::debug(
      "File already exists and no_overwrite option given. Doing nothing.");
    $__ret = { changed => 0 };

    Rex::get_current_connection()->{reporter}->report(
      changed => 0,
      message =>
        "File already exists and no_overwrite option given. Doing nothing."
    );
  }

  elsif ( exists $option->{"content"} && !$is_directory ) {

    # first upload file to tmp location, to get md5 sum.
    # than we can decide if we need to replace the current (old) file.

    my $tmp_file_name = get_tmp_file_name($file);

    my $fh    = file_write($tmp_file_name);
    my @lines = split( qr{$/}, $option->{"content"} );
    for my $line (@lines) {
      $fh->write( $line . $/ );
    }
    $fh->close;

    # now get md5 sums
    eval { $old_md5 = md5($file); };
    $new_md5 = md5($tmp_file_name);

    if ( $new_md5 && $old_md5 && $new_md5 eq $old_md5 ) {
      Rex::Logger::debug(
        "No need to overwrite existing file. Old and new files are the same. $old_md5 eq $new_md5."
      );

      # md5 sums are the same, delete tmp.
      $fs->unlink($tmp_file_name);
      $need_md5 = 0; # we don't need to execute on_change hook

      Rex::get_current_connection()->{reporter}->report(
        changed => 0,
        message =>
          "No need to overwrite existing file. Old and new files are the same. $old_md5 eq $new_md5."
      );
    }
    else {
      $old_md5 ||= "";
      Rex::Logger::debug(
        "Need to use the new file. md5 sums are different. <<$old_md5>> = <<$new_md5>>"
      );

      #### check and run before_change hook
      Rex::Hook::run_hook( file => "before_change", $file, %{$option} );
      ##############################

      if (Rex::is_sudo) {
        my $current_options =
          Rex::get_current_connection_object()->get_current_sudo_options;
        Rex::get_current_connection_object()->push_sudo_options( {} );

        if ( exists $current_options->{user} ) {
          $fs->chown( "$current_options->{user}:", $tmp_file_name );
        }
      }

      $fs->rename( $tmp_file_name, $file );
      Rex::get_current_connection_object()->pop_sudo_options()
        if (Rex::is_sudo);

      $__ret = { changed => 1 };

      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "File updated. old md5: $old_md5, new md5: $new_md5"
      );

      #### check and run after_change hook
      Rex::Hook::run_hook( file => "after_change", $file, %{$option}, $__ret );
      ##############################

    }

  }
  elsif ( exists $option->{"source"} && !$is_directory ) {
    $option->{source} =
      Rex::Helper::Path::get_file_path( $option->{source}, caller() );

    # HOOKS: for this case you have to use the upload hooks!
    $__ret = upload $option->{"source"}, "$file", force => 1;

    $need_md5 = 0 if $__ret->{changed} == 0;
  }

  if ( exists $option->{"ensure"} ) {
    if ( $option->{ensure} eq "present" ) {
      if ( !$fs->is_file($file) ) {

        #### check and run before_change hook
        Rex::Hook::run_hook( file => "before_change", $file, %{$option} );
        ##############################

        my $fh = file_write($file);
        $fh->write("");
        $fh->close;
        $__ret = { changed => 1 };

        Rex::get_current_connection()->{reporter}->report(
          changed => 1,
          message => "file is now present, with no content",
        );

        #### check and run after_change hook
        Rex::Hook::run_hook(
          file => "after_change",
          $file, %{$option}, $__ret
        );
        ##############################

      }
      elsif ( !$__ret->{changed} ) {
        $__ret = { changed => 0 };
        Rex::get_current_connection()->{reporter}->report( changed => 0, );
      }
    }
    elsif ( $option->{ensure} eq "absent" ) {
      $need_md5 = 0;

      #### check and run before_change hook
      Rex::Hook::run_hook( file => "before_change", $file, %{$option} );
      ##############################

      if ( $fs->is_file($file) ) {
        $fs->unlink($file);
        $__ret = { changed => 1 };
        Rex::get_current_connection()->{reporter}->report(
          changed => 1,
          message => "File removed."
        );
      }
      elsif ( $fs->is_dir($file) ) {
        $fs->rmdir($file);
        $__ret = { changed => 1 };
        Rex::get_current_connection()->{reporter}->report(
          changed => 1,
          message => "Directory removed.",
        );
      }
      else {
        $__ret = { changed => 0 };
        Rex::get_current_connection()->{reporter}->report( changed => 0, );
      }

      #### check and run after_change hook
      Rex::Hook::run_hook( file => "after_change", $file, %{$option}, $__ret );
      ##############################

    }
    elsif ( $option->{ensure} eq "directory" ) {
      Rex::Logger::debug("file() should be a directory");
      my %dir_option;
      if ( exists $option->{owner} ) {
        $dir_option{owner} = $option->{owner};
      }
      if ( exists $option->{group} ) {
        $dir_option{group} = $option->{group};
      }
      if ( exists $option->{mode} ) {
        $dir_option{mode} = $option->{mode};
      }

      Rex::Commands::Fs::mkdir( $file, %dir_option, on_change => $on_change );
    }
  }

  if ( !exists $option->{content}
    && !exists $option->{source}
    && $option->{ensure} ne "absent" )
  {

    # no content and no source, so just verify that the file is present
    if ( !$fs->is_file($file) && !$is_directory ) {

      #### check and run before_change hook
      Rex::Hook::run_hook( file => "before_change", $file, %{$option} );
      ##############################

      my $fh = file_write($file);
      $fh->write("");
      $fh->close;

      my $f_type = "file is now present, with no content";
      if ( exists $option->{ensure} && $option->{ensure} eq "directory" ) {
        $f_type = "directory is now present";
      }

      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => $f_type,
      );

      #### check and run after_change hook
      Rex::Hook::run_hook( file => "after_change", $file, %{$option}, $__ret );
      ##############################

    }
  }

  if ( $option->{ensure} ne "absent" ) {

    if ($need_md5) {
      eval { $new_md5 = md5($file); };
    }
    my %stat_old = $fs->stat($file);

    if ( exists $option->{"mode"} ) {
      $fs->chmod( $option->{"mode"}, $file );
    }

    if ( exists $option->{"group"} ) {
      $fs->chgrp( $option->{"group"}, $file );
    }

    if ( exists $option->{"owner"} ) {
      $fs->chown( $option->{"owner"}, $file );
    }

    my %stat_new = $fs->stat($file);

    if ( %stat_old && %stat_new && $stat_old{mode} ne $stat_new{mode} ) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message =>
          "File-System permissions changed from $stat_old{mode} to $stat_new{mode}.",
      );
    }

    if ( %stat_old && %stat_new && $stat_old{uid} ne $stat_new{uid} ) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Owner changed from $stat_old{uid} to $stat_new{uid}.",
      );
    }

    if ( %stat_old && %stat_new && $stat_old{gid} ne $stat_new{gid} ) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Group changed from $stat_old{gid} to $stat_new{gid}.",
      );
    }

  }

  my $on_change_done = 0;

  if ($need_md5) {
    unless ( $old_md5 && $new_md5 && $old_md5 eq $new_md5 ) {
      $old_md5 ||= "";
      $new_md5 ||= "";

      Rex::Logger::debug("File $file has been changed... Running on_change");
      Rex::Logger::debug("old: $old_md5");
      Rex::Logger::debug("new: $new_md5");

      &$on_change($file);

      $on_change_done = 1;

      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Content changed.",
      );

      $__ret = { changed => 1 };
    }
  }

  if ( $__ret->{changed} == 1 && $on_change_done == 0 ) {
    &$on_change($file);
  }
  elsif ( $__ret->{changed} == 0 ) {
    Rex::Logger::debug(
      "File $file has not been changed... Running on_no_change");
    &$on_no_change($file);
  }

  #### check and run after hook
  Rex::Hook::run_hook( file => "after", $file, %{$option}, $__ret );
  ##############################

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "file", name => $file );

  return $__ret->{changed};
}

sub get_tmp_file_name {
  my $file = shift;

  my $dirname  = dirname($file);
  my $filename = ".rex.tmp." . basename($file);

  my $tmp_file_name =
      $dirname eq '.'
    ? $filename
    : Rex::Helper::File::Spec->catfile( $dirname, $filename );

  return $tmp_file_name;
}

=head2 file_write($file_name)

This function opens a file for writing (it will truncate the file if it already exists). It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
   $fh = file_write("/etc/groups");
 };
 
 # catch an error
 if($@) {
   print "An error occurred. $@.\n";
 }
 
 # work with the filehandle
 $fh->write("...");
 $fh->close;

=cut

sub file_write {
  my ($file) = @_;
  $file = resolv_path($file);

  Rex::Logger::debug("Opening file: $file for writing.");

  my $fh = Rex::Interface::File->create;
  if ( !$fh->open( ">", $file ) ) {
    Rex::Logger::debug("Can't open $file for writing.");
    die("Can't open $file for writing.");
  }

  return Rex::FS::File->new( fh => $fh );
}

=head2 file_append($file_name)

=cut

sub file_append {
  my ($file) = @_;
  $file = resolv_path($file);

  Rex::Logger::debug("Opening file: $file for appending.");

  my $fh = Rex::Interface::File->create;

  if ( !$fh->open( ">>", $file ) ) {
    Rex::Logger::debug("Can't open $file for appending.");
    die("Can't open $file for appending.");
  }

  return Rex::FS::File->new( fh => $fh );
}

=head2 file_read($file_name)

This function opens a file for reading. It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
   $fh = read("/etc/groups");
 };
 
 # catch an error
 if($@) {
   print "An error occurred. $@.\n";
 }
 
 # work with the filehandle
 my $content = $fh->read_all;
 $fh->close;

=cut

sub file_read {
  my ($file) = @_;
  $file = resolv_path($file);

  Rex::Logger::debug("Opening file: $file for reading.");

  my $fh = Rex::Interface::File->create;

  if ( !$fh->open( "<", $file ) ) {
    Rex::Logger::debug("Can't open $file for reading.");
    die("Can't open $file for reading.");
  }

  return Rex::FS::File->new( fh => $fh );
}

=head2 cat($file_name)

This function returns the complete content of $file_name as a string.

 print cat "/etc/passwd";

=cut

sub cat {
  my ($file) = @_;
  $file = resolv_path($file);

  my $fh = file_read($file);
  unless ($fh) {
    die("Can't open $file for reading");
  }
  my $content = $fh->read_all;
  $fh->close;

  return $content;
}

=head2 delete_lines_matching($file, $regexp)

Delete lines that match $regexp in $file.

 task "clean-logs", sub {
    delete_lines_matching "/var/log/auth.log" => "root";
 };

=cut

sub delete_lines_matching {
  my ( $file, @m ) = @_;
  $file = resolv_path($file);

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "delete_lines_matching", name => $file );

  for (@m) {
    if ( ref($_) ne "Regexp" ) {
      $_ = qr{\Q$_\E};
    }
  }

  my $fs = Rex::Interface::Fs->create;

  my %stat = $fs->stat($file);

  if ( !$fs->is_file($file) ) {
    Rex::Logger::info("File: $file not found.");
    die("$file not found");
  }

  if ( !$fs->is_writable($file) ) {
    Rex::Logger::info("File: $file not writable.");
    die("$file not writable");
  }

  my $nl      = $/;
  my @content = split( /$nl/, cat($file) );

  my $old_md5 = "";
  eval { $old_md5 = md5($file); };

  my @new_content;

OUT:
  for my $line (@content) {
  IN:
    for my $match (@m) {
      if ( $line =~ $match ) {
        next OUT;
      }
    }

    push @new_content, $line;
  }

  file $file,
    content => join( $nl, @new_content ),
    owner   => $stat{uid},
    group   => $stat{gid},
    mode    => $stat{mode};

  my $new_md5 = "";
  eval { $new_md5 = md5($file); };

  if ( $new_md5 ne $old_md5 ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Content changed.",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "delete_lines_matching", name => $file );
}

=head2 delete_lines_according_to($search, $file, @options)

This is the successor of the delete_lines_matching() function. This function also allows the usage of on_change and on_no_change hooks.

It will search for $search in $file and remove the found lines. If on_change hook is present it will execute this if the file was changed.

 task "cleanup", "server1", sub {
   delete_lines_according_to qr{^foo:}, "/etc/passwd",
    on_change => sub {
      say "removed user foo.";
    };
 };

=cut

sub delete_lines_according_to {
  my ( $search, $file, @options ) = @_;
  $file = resolv_path($file);

  my $option       = {@options};
  my $on_change    = $option->{on_change}    || undef;
  my $on_no_change = $option->{on_no_change} || undef;

  my ( $old_md5, $new_md5 );

  if ($on_change) {
    $old_md5 = md5($file);
  }

  delete_lines_matching( $file, $search );

  if ( $on_change || $on_no_change ) {
    $new_md5 = md5($file);

    if ( $old_md5 ne $new_md5 ) {
      &$on_change($file) if $on_change;
    }
    else {
      &$on_no_change($file) if $on_no_change;
    }
  }

}

=head2 append_if_no_such_line($file, $new_line, @regexp)

Append $new_line to $file if none in @regexp is found. If no regexp is
supplied, the line is appended unless there is already an identical line
in $file.

 task "add-group", sub {
   append_if_no_such_line "/etc/groups", "mygroup:*:100:myuser1,myuser2", on_change => sub { service sshd => "restart"; };
 };

Since 0.42 you can use named parameters as well

 task "add-group", sub {
   append_if_no_such_line "/etc/groups",
     line  => "mygroup:*:100:myuser1,myuser2",
     regexp => qr{^mygroup},
     on_change => sub {
                say "file was changed, do something.";
              };
 
   append_if_no_such_line "/etc/groups",
     line  => "mygroup:*:100:myuser1,myuser2",
     regexp => [qr{^mygroup:}, qr{^ourgroup:}]; # this is an OR
 };

=cut

sub append_if_no_such_line {
  _append_or_update( 'append_if_no_such_line', @_ );
}

=head2 append_or_amend_line($file, $line, @regexp)

Similar to L<append_if_no_such_line>, but if the line in the regexp is
found, it will be updated. Otherwise, it will be appended.

 task "update-group", sub {
   append_or_amend_line "/etc/groups",
     line  => "mygroup:*:100:myuser3,myuser4",
     regexp => qr{^mygroup},
     on_change => sub {
       say "file was changed, do something.";
     },
     on_no_change => sub {
       say "file was not changed, do something.";
     };
 };

=cut

sub append_or_amend_line {
  _append_or_update( 'append_or_amend_line', @_ );
}

sub _append_or_update {
  my $action = shift;
  my $file   = shift;

  $file = resolv_path($file);
  my ( $new_line, @m );

  # check if parameters are in key => value format
  my ( $option, $on_change, $on_no_change );

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $action, name => $file );

  eval {
    no warnings;
    $option = {@_};

    # if there is no line parameter, it is the old parameter format
    # so go dieing
    if ( !exists $option->{line} ) {
      die;
    }
    $new_line = $option->{line};
    if ( exists $option->{regexp} && ref $option->{regexp} eq "Regexp" ) {
      @m = ( $option->{regexp} );
    }
    elsif ( ref $option->{regexp} eq "ARRAY" ) {
      @m = @{ $option->{regexp} };
    }
    $on_change    = $option->{on_change}    || undef;
    $on_no_change = $option->{on_no_change} || undef;
    1;
  } or do {
    ( $new_line, @m ) = @_;

    # check if something in @m (the regexpes) is named on_change or on_no_change
    for my $option ( [ on_change => \$on_change ],
      [ on_no_change => \$on_no_change ] )
    {
      for ( my $i = 0 ; $i < $#m ; $i++ ) {
        if ( $m[$i] eq $option->[0] && ref( $m[ $i + 1 ] ) eq "CODE" ) {
          ${ $option->[1] } = $m[ $i + 1 ];
          splice( @m, $i, 2 );
          last;
        }
      }
    }
  };

  unless ( defined $new_line ) {
    my ( undef, undef, undef, $subroutine ) = caller(1);
    $subroutine =~ s/^.*:://;
    die "Undefined new line while trying to run $subroutine on $file";
  }

  my $fs = Rex::Interface::Fs->create;

  my %stat = $fs->stat($file);

  my ( $old_md5, $ret );
  $old_md5 = md5($file);

  # slow but secure way
  my $content;
  eval {
    $content = [ split( /\n/, cat($file) ) ];
    1;
  } or do {
    $ret = 1;
  };

  if ( !@m ) {
    push @m, qr{\Q$new_line\E};
  }

  my $found;
  for my $line ( 0 .. $#{$content} ) {
    for my $match (@m) {
      if ( ref($match) ne "Regexp" ) {
        $match = qr{$match};
      }
      if ( $content->[$line] =~ $match ) {
        $found = 1;
        last if $action eq 'append_if_no_such_line';
        $content->[$line] = "$new_line";
      }
    }
  }

  my $new_md5;
  if ( $action eq 'append_if_no_such_line' && $found ) {
    $new_md5 = $old_md5;
  }
  else {
    push @$content, "$new_line" unless $found;

    file $file,
      content => join( "\n", @$content ),
      owner   => $stat{uid},
      group   => $stat{gid},
      mode    => $stat{mode};
    $new_md5 = md5($file);
  }

  if ( $on_change || $on_no_change ) {
    if ( $old_md5 && $new_md5 && $old_md5 ne $new_md5 ) {
      if ($on_change) {
        $old_md5 ||= "";
        $new_md5 ||= "";

        Rex::Logger::debug("File $file has been changed... Running on_change");
        Rex::Logger::debug("old: $old_md5");
        Rex::Logger::debug("new: $new_md5");
        &$on_change($file);
      }
    }
    elsif ($on_no_change) {
      $new_md5 ||= "";

      Rex::Logger::debug(
        "File $file has not been changed (md5 $new_md5)... Running on_no_change"
      );
      &$on_no_change($file);
    }
  }

  if ( $old_md5 && $new_md5 && $old_md5 ne $new_md5 ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Content changed.",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => $action, name => $file );
}

=head2 extract($file [, %options])

This function extracts a file. The target directory optionally specified with the `to` option will be created automatically.

Supported formats are .box, .tar, .tar.gz, .tgz, .tar.Z, .tar.bz2, .tbz2, .zip, .gz, .bz2, .war, .jar.

 task prepare => sub {
   extract "/tmp/myfile.tar.gz",
    owner => "root",
    group => "root",
    to   => "/etc";
 
   extract "/tmp/foo.tgz",
    type => "tgz",
    mode => "g+rwX";
 };

Can use the type=> option if the file suffix has been changed. (types are tar, tgz, tbz, zip, gz, bz2)

=cut

sub extract {
  my ( $file, %option ) = @_;
  $file = resolv_path($file);

  my $pre_cmd = "";
  my $to      = ".";
  my $type    = "";

  if ( $option{chdir} ) {
    $to = $option{chdir};
  }

  if ( $option{to} ) {
    $to = $option{to};
  }
  $to = resolv_path($to);

  if ( $option{type} ) {
    $type = $option{type};
  }

  Rex::Commands::Fs::mkdir($to);
  $pre_cmd = "cd $to; ";

  my $exec = Rex::Interface::Exec->create;
  my $cmd  = "";

  if ( $type eq 'tgz'
    || $file =~ m/\.tar\.gz$/
    || $file =~ m/\.tgz$/
    || $file =~ m/\.tar\.Z$/ )
  {
    $cmd = "${pre_cmd}gunzip -c $file | tar -xf -";
  }
  elsif ( $type eq 'tbz' || $file =~ m/\.tar\.bz2/ || $file =~ m/\.tbz2/ ) {
    $cmd = "${pre_cmd}bunzip2 -c $file | tar -xf -";
  }
  elsif ( $type eq 'tar' || $file =~ m/\.(tar|box)/ ) {
    $cmd = "${pre_cmd}tar -xf $file";
  }
  elsif ( $type eq 'zip' || $file =~ m/\.(zip|war|jar)$/ ) {
    $cmd = "${pre_cmd}unzip -o $file";
  }
  elsif ( $type eq 'gz' || $file =~ m/\.gz$/ ) {
    $cmd = "${pre_cmd}gunzip -f $file";
  }
  elsif ( $type eq 'bz2' || $file =~ m/\.bz2$/ ) {
    $cmd = "${pre_cmd}bunzip2 -f $file";
  }
  else {
    Rex::Logger::info("File not supported.");
    die("File ($file) not supported.");
  }

  $exec->exec($cmd);

  my $fs = Rex::Interface::Fs->create;
  if ( $option{owner} ) {
    $fs->chown( $option{owner}, $to, recursive => 1 );
  }

  if ( $option{group} ) {
    $fs->chgrp( $option{group}, $to, recursive => 1 );
  }

  if ( $option{mode} ) {
    $fs->chmod( $option{mode}, $to, recursive => 1 );
  }

}

=head2 sed($search, $replace, $file)

Search some string in a file and replace it.

 task sar => sub {
   # this will work line by line
   sed qr{search}, "replace", "/var/log/auth.log";
 
   # to use it in a multiline way
   sed qr{search}, "replace", "/var/log/auth.log",
    multiline => TRUE;
 };

Like similar file management commands, it also supports C<on_change> and C<on_no_change> hooks.

=cut

sub sed {
  my ( $search, $replace, $file, @option ) = @_;
  $file = resolv_path($file);
  my $options = {};

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "sed", name => $file );

  if ( ref( $option[0] ) ) {
    $options = $option[0];
  }
  else {
    $options = {@option};
  }

  my $on_change    = $options->{"on_change"}    || undef;
  my $on_no_change = $options->{"on_no_change"} || undef;

  my @content;

  if ( exists $options->{multiline} ) {
    $content[0] = cat($file);
    $content[0] =~ s/$search/$replace/gms;
  }
  else {
    @content = split( /\n/, cat($file) );
    for (@content) {
      s/$search/$replace/;
    }
  }

  my $fs   = Rex::Interface::Fs->create;
  my %stat = $fs->stat($file);

  my $ret = file(
    $file,
    content      => join( "\n", @content ),
    on_change    => $on_change,
    on_no_change => $on_no_change,
    owner        => $stat{uid},
    group        => $stat{gid},
    mode         => $stat{mode}
  );

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "sed", name => $file );

  return $ret;
}

1;
