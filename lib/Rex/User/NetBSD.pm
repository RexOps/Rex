#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::User::NetBSD;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::User::Linux;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;


use base qw(Rex::User::Linux);

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
      Rex::Logger::debug("Changing password of $user.");

      $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
      $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("usermod -p \$(pwhash '" . $data->{password} . "') $user\nexit \$?\n");
      $fh->close;

      run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   if(exists $data->{crypt_password}) {
      Rex::Logger::debug("Setting encrypted password of $user");

      $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
      $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("usermod -p '" . $data->{crypt_password} . "' $user\nexit \$?\n");
      $fh->close;

      run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   return $self->get_uid($user);

}

sub rm_user {
   my ($self, $user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my %user_info = $self->get_user($user);

   my $cmd = "userdel";

   if(exists $data->{delete_home}) {
      $cmd .= " -r";
   }

   run $cmd . " " . $user;

   if(exists $data->{delete_home} && is_dir($user_info{home})) {
      Rex::Logger::debug("userdel doesn't deleted home. removing it now by hand...");
      rmdir $user_info{home};  
   }

   if($? != 0) {
      die("Error deleting user $user");
   }

}



1;
