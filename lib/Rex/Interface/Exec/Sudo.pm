#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::Sudo;
   
use strict;
use warnings;

use Rex::Config;
use Rex::Interface::Exec::Local;
use Rex::Interface::Exec::SSH;

use Rex::Interface::File::Local;
use Rex::Interface::File::SSH;

use Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $cmd, $path) = @_;

   if($path) { $path = "PATH=$path" }
   $path ||= "";

   my ($exec, $file);
   if(Rex::is_ssh()) {
      $exec = Rex::Interface::Exec->create("SSH");
      $file = Rex::Interface::File->create("SSH");
   }
   else {
      $exec = Rex::Interface::Exec->create("Local");
      $file = Rex::Interface::File->create("Local");
   }

   my $sudo_password = task->get_sudo_password;
   my $random_string = get_random(length($sudo_password), 'a' .. 'z');
   my $crypt = $sudo_password ^ $random_string;

   my $random_file = "/tmp/" . get_random(16, 'a' .. 'z') . ".sudo.tmp";

   $file->open('>', $random_file);
   $file->write(qq~#!/usr/bin/perl
unlink \$0;
my \$rnd = '$random_string';
print \$ARGV[0] ^ \$rnd;
print "\\n"
   ~);
   $file->close;
   

   return $exec->exec("perl $random_file $crypt | sudo -p '' -S sh -c 'LC_ALL=C $path $cmd'");
}

1;
