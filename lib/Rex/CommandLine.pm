#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::CommandLine;

use strict;
use warnings;
use Rex -base;

require Rex::Args;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub call {
   my ($self, $command, %option) = @_;

   $Rex::Args::CLEANUP=1;

   Rex::Args->import(
      L => {},
   ); 

no strict 'refs';
   my %opts = Rex::Args->getopts;
   #$::QUIET = 1;

   if(exists $option{join_argv}) {
      @ARGV = join($option{join_argv}, @ARGV);
   }

   if(exists $opts{L}) {
      return LOCAL {
         return &$command(@ARGV, Rex::Args->get);
      };
   }
   else {
      Rex::connect(
         server      => $ENV{REX_REMOTE_HOST},
         user        => $ENV{REX_REMOTE_USER},
         password    => $ENV{REX_REMOTE_PASSWORD},
         private_key => $ENV{REX_REMOTE_PRIVATE_KEY},
         public_key  => $ENV{REX_REMOTE_PUBLIC_KEY},
      );

      return &$command(@ARGV, Rex::Args->get);
   }
}

1;
