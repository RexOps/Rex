#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Fs::Base;
   
use strict;
use warnings;

use Rex::Interface::Exec;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub ls          { die("Must be implemented by Interface Class"); }
sub unlink      { die("Must be implemented by Interface Class"); }
sub mkdir       { die("Must be implemented by Interface Class"); }
sub glob        { die("Must be implemented by Interface Class"); }
sub rename      { die("Must be implemented by Interface Class"); }
sub stat        { die("Must be implemented by Interface Class"); }
sub readlink    { die("Must be implemented by Interface Class"); }
sub is_file     { die("Must be implemented by Interface Class"); }
sub is_dir      { die("Must be implemented by Interface Class"); }
sub is_readable { die("Must be implemented by Interface Class"); }
sub is_writable { die("Must be implemented by Interface Class"); }
sub upload { die("Must be implemented by Interface Class"); }
sub download { die("Must be implemented by Interface Class"); }


sub ln {
   my ($self, $from, $to) = @_;

   Rex::Logger::debug("Symlinking files: $to -> $from");
   my $exec = Rex::Interface::Exec->create;
   $exec->exec("ln -snf $from $to");

   if($? == 0) { return 1; }
}


sub rmdir {
   my ($self, @dirs) = @_;

   Rex::Logger::debug("Removing directories: " . join(", ", @dirs));
   my $exec = Rex::Interface::Exec->create;
   $exec->exec("/bin/rm -rf " . join(" ", @dirs));

   if($? == 0) { return 1; }
}

sub chown {
   my ($self, $user, $file, @opts) = @_;

   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("chown $recursive $user $file");

   if($? == 0) { return 1; }
}

sub chgrp {
   my ($self, $group, $file, @opts) = @_;
   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("chgrp $recursive $group $file");

   if($? == 0) { return 1; }
}

sub chmod {
   my ($self, $mode, $file, @opts) = @_;
   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("chmod $recursive $mode $file");

   if($? == 0) { return 1; }
}

sub cp {
   my ($self, $source, $dest) = @_;

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("cp -R $source $dest");

   if($? == 0) { return 1; }
}

1;
