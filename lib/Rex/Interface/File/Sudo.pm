#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::File::Sudo;
   
use strict;
use warnings;

use Fcntl;
use File::Basename;
require Rex::Commands;
use Rex::Interface::Fs;
use Rex::Interface::File::Base;
use base qw(Rex::Interface::File::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub open {
   my ($self, $mode, $file) = @_;

   if(my $ssh = Rex::is_ssh()) {
      if(ref $ssh eq "Net::OpenSSH") {
         $self->{fh} = Rex::Interface::File->create("OpenSSH");
      }
      else {
         $self->{fh} = Rex::Interface::File->create("SSH");
      }
   }
   else {
      $self->{fh} = Rex::Interface::File->create("Local");
   }

   $self->{mode} = $mode;
   $self->{file} = $file;
   $self->{rndfile} = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".sudo.tmp";
   if($self->_fs->is_file($file)) {
      # resolving symlinks
      while(my $link = $self->_fs->readlink($file)) {
         if($link !~ m/^\//) {
            $file = dirname($file) . "/" . $link;
         }
         else {
            $file = $link;
         }
         $link = $self->_fs->readlink($link);
      }
      $self->{file_stat} = { $self->_fs->stat($self->{file}) };

      $self->_fs->cp($file, $self->{rndfile});
      $self->_fs->chmod(600, $self->{rndfile});
      $self->_fs->chown(Rex::Commands::connection->get_auth_user, $self->{rndfile});
   }

   $self->{fh}->open($mode, $self->{rndfile});

   return $self->{fh};
}

sub read {
   my ($self, $len) = @_;

   return $self->{fh}->read($len);
}

sub write {
   my ($self, $buf) = @_;
   $self->{fh}->write($buf);
}

sub seek {
   my ($self, $pos) = @_;
   $self->{fh}->seek($pos);
}

sub close {
   my ($self) = @_;

   return unless $self->{fh};

   if(exists $self->{mode} && ( $self->{mode} eq ">" || $self->{mode} eq ">>") ) {
      my $exec = Rex::Interface::Exec->create;
      $self->_fs->rename($self->{rndfile}, $self->{file});
      if($self->{file_stat}) {
         my %stat = %{ $self->{file_stat} };
         $self->_fs->chmod($stat{mode}, $self->{file});
         $self->_fs->chown($stat{uid}, $self->{file});
         $self->_fs->chgrp($stat{gid}, $self->{file});
      }

      #$exec->exec("cat " . $self->{rndfile} . " >'" . $self->{file} . "'");
   }
   
   $self->{fh}->close;
   $self->{fh} = undef;
   
   $self->_fs->unlink($self->{rndfile});

   $self = undef;
}

sub _fs {
   my ($self) = @_;
   return Rex::Interface::Fs->create("Sudo");
}

1;
