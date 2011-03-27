#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Rsync;

use strict;
use warnings;

use Expect;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sync);


sub sync {
   my ($source, $dest, $opt) = @_;

   my $current_connection = Rex::get_current_connection();
   my $cmd;

   if($opt && exists $opt->{'download'} && $opt->{'download'} == 1) {
      Rex::Logger::debug("Downloading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $source . " " . $dest;
   }
   else {
      Rex::Logger::debug("Uploading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats $source " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $dest;
   }

   my $pass = Rex::Config->get_password;
   my @expect_options = ();

   if(Rex::Config->get_password_auth) {
      $cmd = sprintf($cmd, 'ssh');
      push(@expect_options, [
                              qr{password: $},
                              sub {
                                 print STDERR ">> WANT PASSWORD\n";
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      
      );
   }
   else {
      $cmd = sprintf($cmd, 'ssh -i ' . Rex::Config->get_private_key);
      push(@expect_options, [
                              qr{Enter passphrase for key.*: $},
                              sub {
                                 print STDERR ">> WANT PASSPHRASE\n";
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      );
   }

   Rex::Logger::debug("cmd: $cmd");

   eval {
      local $SIG{ALRM} = sub { die("Error in authentication or rsync timed out...\n"); };
      alarm Rex::Config->get_timeout;

      my $exp = Expect->spawn($cmd) or die($!);
      $exp->expect(undef, @expect_options);
   };

   if($@) {
      Rex::Logger::info($@);
   }

}


1;
