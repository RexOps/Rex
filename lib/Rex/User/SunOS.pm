#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::User::SunOS;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::User::OpenBSD;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;


use base qw(Rex::User::OpenBSD);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub create_user {
   my ($self, $user, $data) = @_;

   my $cmd;


   if(! defined $self->get_uid($user)) {
      Rex::Logger::debug("User $user does not exists. Creating it now.");
      $cmd = "useradd ";

      if(exists $data->{system}) {
         $cmd .= " -r";
      }
   }
   else {
      Rex::Logger::debug("User $user already exists. Updating...");

      $cmd = "usermod ";
   }

   if(exists $data->{uid}) {
      $cmd .= " -u " . $data->{uid};
   }

   if(exists $data->{home}) {
      $cmd .= " -d " . $data->{home};

      if(
         ! (
            (exists $data->{"no-create-home"} && $data->{"no-create-home"})
               ||
            (exists $data->{"no_create_home"} && $data->{"no_create_home"})
         )
        ) {
         $cmd .= " -m ";
      }
   }

   if(exists $data->{comment}) {
      $cmd .= " -c '" . $data->{comment} . "'";
   }

   if(exists $data->{expire}) {
      $cmd .= " -e '" . $data->{expiredate} . "'";
   }

   if(exists $data->{groups}) {
      my @groups = @{$data->{groups}};
      my $pri_group = shift @groups;

      $cmd .= " -g $pri_group";

      if(@groups) {
         $cmd .= " -G " . join(",", @groups);
      }
   }
 
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write("$cmd $user\nexit \$?\n");
   $fh->close;

   run "/bin/sh $rnd_file";
   if($? == 0) {
      Rex::Logger::debug("User $user created/updated.");
   }
   else {
      Rex::Logger::info("Error creating/updating user $user", "warn");
      die("Error creating/updating user $user");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

   if(exists $data->{password}) {
      my $expect_path;

      if(Rex::get_cache()->can_run("/usr/local/bin/expect")) {
         $expect_path = "/usr/local/bin/expect";
      }
      elsif(Rex::get_cache()->can_run("/usr/bin/expect")) {
         $expect_path = "/usr/bin/expect";
      }

      if($expect_path) {
         my $fh = file_write "/tmp/chpasswd";
         $fh->write(qq~#!$expect_path --
# Input: username password
set USER [lindex \$argv 0]
set PASS [lindex \$argv 1] 

if { \$USER == "" || \$PASS == "" }  {
   puts "Usage:  /tmp/chpasswd username password\n"
   exit 1
 }

spawn passwd \$USER 
expect "assword:"
send "\$PASS\r"
expect "assword:"
send "\$PASS\r"
expect eof
~);
         $fh->close;

         $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
         $fh = Rex::Interface::File->create;
         $fh->open(">", $rnd_file);
         $fh->write("/tmp/chpasswd $user '" . $data->{"password"} . "'\nexit \$?\n");
         $fh->close;

         chmod 700, "/tmp/chpasswd";
         run "/bin/sh $rnd_file";
         if($? != 0) { die("Error changing user's password."); }

         rm "/tmp/chpasswd";
         rm "$rnd_file";
      }
      else {
         die("No expect found in /usr/local/bin or /usr/bin. Can't set user password.");
      }
   }

   return $self->get_uid($user);

}

1;
