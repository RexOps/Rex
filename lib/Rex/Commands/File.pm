#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::File - Transparent File Manipulation

=head1 DESCRIPTION

With this module you can manipulate files.

=head1 SYNOPSIS

 task "read-passwd", "server01", sub {
    my $fh = file_read "/etc/passwd";
    for my $line = ($fh->read_all) {
       print $line;
    }
    $fh->close;
 };

 task "read-passwd2", "server01", sub {
    say cat "/etc/passwd";
 };
 
 
 task "write-passwd", "server01", sub {
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
    mode   => 400,
    on_change => sub { say "File was changed."; };
 
=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::File;

use strict;
use warnings;
use Fcntl;

require Rex::Exporter;
use Data::Dumper;
use Rex::Config;
use Rex::FS::File;
use Rex::Commands::Upload;
use Rex::Commands::MD5;
use Rex::File::Parser::Data;

use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;

use File::Basename qw(dirname);

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(file_write file_read file_append 
               cat sed
               delete_lines_matching append_if_no_such_line
               file template
               extract);

use vars qw(%file_handles);

=item template($file, @params)

Parse a template and return the content.

 my $content = template("/files/templates/vhosts.tpl", 
                     name => "test.lan",
                     webmaster => 'webmaster@test.lan');

=cut
sub template {
   my ($file, @params) = @_;
   my $param = { @params };

   unless($file =~ m/^\// || $file =~ m/^\@/) {
      # path is relative and no template
      Rex::Logger::debug("Relativ path $file");
      my ($caller_package, $caller_file, $caller_line) = caller;

      # check if it is a module
      my $module_path = Rex::get_module_path($caller_package);
      if($module_path) {
         $file = "$module_path/$file";
      }
      else {
         $file = dirname($caller_file) . "/" . $file;
      }

      Rex::Logger::debug("New filename: $file");
   }

   # if there is a file called filename.environment then use this file
   # ex: 
   # $content = template("files/hosts.tpl");
   # 
   # rex -E live ...
   # will first look if files/hosts.tpl.live is available, if not it will
   # use files/hosts.tpl
   if(-f "$file." . Rex::Config->get_environment) {
      $file = "$file." . Rex::Config->get_environment;
   }

   my $content;

   if(-f $file) {
      $content = eval { local(@ARGV, $/) = ($file); <>; };
   }
   elsif($file =~ m/^\@/) {
      my @caller = caller(0);
      my $file_content = eval { local(@ARGV, $/) = ($caller[1]); <>; };
      my ($data) = ($file_content =~ m/.*__DATA__(.*)/ms);
      my $fp = Rex::File::Parser::Data->new(data => [ split(/\n/, $data) ]);
      my $snippet_to_read = substr($file, 1);
      $content = $fp->read($snippet_to_read);
   }
   else {
      die("$file not found");
   }

   my %template_vars = _get_std_template_vars($param);

   return Rex::Config->get_template_function()->($content, \%template_vars);
}

sub _get_std_template_vars {
   my ($param) = @_;

   my %merge1 = %{$param || {}};
   my %merge2 = Rex::Helper::System::info();
   my %template_vars = (%merge1, %merge2);

   return %template_vars;
}

=item file($file_name, %options)

This function is the successor of I<install file>. Please use this function to upload files to you server.

 task "prepare", "server1", "server2", sub {
    file "/file/on/remote/machine",
       source => "/file/on/local/machine";
       
    file "/etc/hosts",
       content => template("templates/etc/hosts.tpl"),
       owner   => "user",
       group   => "group",
       mode    => 700,
       on_change => sub { say "Something was changed." };
        
    file "/etc/motd",
       content => `fortune`;
      
    file "/etc/httpd/conf/httpd.conf",
       source => "/files/etc/httpd/conf/httpd.conf",
       on_change => sub { service httpd => "restart"; };
 };

If I<source> is relative it will search from the location of your I<Rexfile>.

=cut
sub file {
   my ($file, @options) = @_;
   my $option = { @options };

   my $need_md5 = ($option->{"on_change"} ? 1 : 0);
   my $on_change = $option->{"on_change"} || sub {};

   my $fs = Rex::Interface::Fs->create;

   my ($new_md5, $old_md5);
   if($need_md5) {
      eval {
         $old_md5 = md5($file);
      };
   }

   if(exists $option->{"content"}) {

      my $fh = file_write($file);
      my @lines = split(qr{$/}, $option->{"content"});
      for my $line (@lines) {
         $fh->write($line . $/);
      }
      $fh->close;
   }
   elsif(exists $option->{"source"}) {
      unless($option->{source} =~ m/^\//) {
         # path is relative
         Rex::Logger::debug("Relativ path " . $option->{source});
         my ($caller_package, $caller_file, $caller_line) = caller;
         my $d = dirname($caller_file) . "/" . $option->{source};

         Rex::Logger::debug("New filename: $d");
         $option->{source} = $d;
      }

      upload $option->{"source"}, "$file";
   }

   if($need_md5) {
      eval {
         $new_md5 = md5($file);
      };
   }

   if(exists $option->{"mode"}) {
      $fs->chmod($option->{"mode"}, $file);
   }

   if(exists $option->{"group"}) {
      $fs->chgrp($option->{"group"}, $file);
   }

   if(exists $option->{"owner"}) {
      $fs->chown($option->{"owner"}, $file);
   }

   if($need_md5) {
      unless($old_md5 && $new_md5 && $old_md5 eq $new_md5) {
         $old_md5 ||= "";
         $new_md5 ||= "";

         Rex::Logger::debug("File $file has been changed... Running on_change");
         Rex::Logger::debug("old: $old_md5");
         Rex::Logger::debug("new: $new_md5");

         &$on_change($file);
      }
   }
}

=item file_write($file_name)

This function opens a file for writing (it will truncate the file if it already exists). It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
    $fh = file_write("/etc/groups");
 };
 
 # catch an error
 if($@) {
    print "An error occured. $@.\n";
    exit;
 }
 
 # work with the filehandle
 $fh->write("...");
 $fh->close;

=cut

sub file_write {
   my ($file) = @_;

   Rex::Logger::debug("Opening file: $file for writing.");

   my $fh = Rex::Interface::File->create;
   if( ! $fh->open(">", $file)) {
      Rex::Logger::debug("Can't open $file for writing.");
      die("Can't open $file for writing.");
   }

   return Rex::FS::File->new(fh => $fh);
}

=item file_append($file_name)

=cut

sub file_append {
   my ($file) = @_;

   Rex::Logger::debug("Opening file: $file for appending.");

   my $fh = Rex::Interface::File->create;

   if( ! $fh->open(">>", $file)) {
      Rex::Logger::debug("Can't open $file for appending.");
      die("Can't open $file for appending.");
   }

   return Rex::FS::File->new(fh => $fh);
}

=item file_read($file_name)

This function opens a file for reading. It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
    $fh = read("/etc/groups");
 };
 
 # catch an error
 if($@) {
    print "An error occured. $@.\n";
    exit;
 }
 
 # work with the filehandle
 my $content = $fh->read_all;
 $fh->close;

=cut

sub file_read {
   my ($file) = @_;

   Rex::Logger::debug("Opening file: $file for reading.");

   my $fh = Rex::Interface::File->create;

   if( ! $fh->open("<", $file)) {
      Rex::Logger::debug("Can't open $file for reading.");
      die("Can't open $file for reading.");
   }

   return Rex::FS::File->new(fh => $fh);
}

=item cat($file_name)

This function returns the complete content of $file_name as a string.

 print cat "/etc/passwd";

=cut

sub cat {
   my ($file) = @_;

   my $fh = file_read($file);
   unless($fh) {
      die("Can't open $file for reading");
   }
   my $content = $fh->read_all;
   $fh->close;

   return $content;
}

=item delete_lines_matching($file, $regexp)

Delete lines that match $regexp in $file.

 task "clean-logs", sub {
     delete_lines_matching "/var/log/auth.log" => "root";
 };

=cut
sub delete_lines_matching {
   my ($file, @m) = @_;
   my $fs = Rex::Interface::Fs->create;

   if(! $fs->is_file($file)) {
      Rex::Logger::info("File: $file not found.");
      die("$file not found");
   }

   if(! $fs->is_writable($file)) {
      Rex::Logger::info("File: $file not writable.");
      die("$file not writable");
   }

   my $nl = $/;
   my @content = split(/$nl/, cat ($file));

   my $fh = file_write $file;
   unless($fh) {
      die("Can't open $file for writing");
   }

   OUT:
   for my $line (@content) {
      IN:
      for my $match (@m) {
         if(! ref($match) eq "Regexp") {
            $match = qr{$match};
         }

         if($line =~ $match) {
            next OUT;
         }
      }

      $fh->write($line . $nl);
   }
   $fh->close;
}

=item append_if_no_such_line($file, $new_line, @regexp)

Append $new_line to $file if none in @regexp is found.

 task "add-group", sub {
    append_if_no_such_line "/etc/groups", "mygroup:*:100:myuser1,myuser2", on_change => sub { service sshd => "restart"; };
 };

=cut
sub append_if_no_such_line {
   my ($file, $new_line, @m) = @_;

   my $fs = Rex::Interface::Fs->create;

   if(! $fs->is_file($file)) {
      Rex::Logger::info("File: $file not found.");
      die("$file not found");
   }

   if(! $fs->is_writable($file)) {
      Rex::Logger::info("File: $file not writable.");
      die("$file not writable");
   }

   my $nl = $/;
   my @content = split(/$nl/, cat ($file));
   my $i;
   my $on_change = sub {};

   for my $line (@content) {
      $i = 0;
      for my $match (@m) {
         $i++;
         if(! ref($match) eq "Regexp") {
            $match = qr{$match};
         }
         if ( $match eq "on_change" && ref($m[$i]) eq "CODE" ) {
             $on_change = $m[$i];
             next;
         }
         if($line =~ $match) {
            return 0;
         }
      }
   }

   push @content, $new_line;
   my $fh = file_write $file;
   unless($fh) {
      die("Can't open $file for writing");
   }
   $fh->write(join($nl, @content));
   $fh->close;

   &$on_change();
}

=item extract($file [, %options])

This function extracts a file. Supported formats are .tar.gz, .tgz, .tar.Z, .tar.bz2, .tbz2, .zip, .gz, .bz2, .war, .jar.

 task prepare => sub {
    extract "/tmp/myfile.tar.gz",
      owner => "root",
      group => "root",
      to    => "/etc";

    extract "/tmp/foo.tgz",
      type => "tgz",
      mode => "g+rwX";
 };
 
Can use the type=> option if the file suffix has been changed. (types are tgz, tbz, zip, gz, bz2)

=cut
sub extract {
   my ($file, %option) = @_;

   my $pre_cmd = "";
   my $to = ".";
   my $type = "";

   if($option{chdir}) {
      $to = $option{chdir};
   }

   if($option{to}) {
      $to = $option{to};
   }

   if($option{type}) {
      $type = $option{type};
   }

   $pre_cmd = "cd $to; ";

   my $exec = Rex::Interface::Exec->create;
   my $cmd = "";

   if($type eq 'tgz' || $file =~ m/\.tar\.gz$/ || $file =~ m/\.tgz$/ || $file =~ m/\.tar\.Z$/) {
      $cmd = "${pre_cmd}gunzip -c $file | tar -xf -";
   }
   elsif($type eq 'tbz' || $file =~ m/\.tar\.bz2/ || $file =~ m/\.tbz2/) {
      $cmd = "${pre_cmd}bunzip2 -c $file | tar -xf -";
   }
   elsif($type eq 'tar' || $file =~ m/\.(tar|box)/) {
      $cmd = "${pre_cmd}tar -xf $file";
   }
   elsif($type eq 'zip' || $file =~ m/\.(zip|war|jar)$/) {
      $cmd = "${pre_cmd}unzip -o $file";
   }
   elsif($type eq 'gz' || $file =~ m/\.gz$/) {
      $cmd = "${pre_cmd}gunzip -f $file";
   }
   elsif($type eq 'bz2' || $file =~ m/\.bz2$/) {
      $cmd = "${pre_cmd}bunzip2 -f $file";
   }
   else {
      Rex::Logger::info("File not supported.");
      die("File ($file) not supported.");
   }

   $exec->exec($cmd);

   my $fs = Rex::Interface::Fs->create;
   if($option{owner}) {
      $fs->chown($option{owner}, $to, recursive => 1);
   }

   if($option{group}) {
      $fs->chgrp($option{group}, $to, recursive => 1);
   }

   if($option{mode}) {
      $fs->chmod($option{mode}, $to, recursive => 1);
   }

}

=item sed($search, $replace, $file)

Search some string in a file and replace it.

 task sar => sub {
    sed qr{search}, "replace", "/var/log/auth.log";
 };

=cut
sub sed {
   my ($search, $replace, $file, @options) = @_;
   my $content = cat($file);
   my $option = { @options };

   my $on_change = $option->{"on_change"} || sub {};
   $content =~ s/$search/$replace/gms;

   file($file, content => $content, on_change => $on_change);
}

=back

=cut

1;
