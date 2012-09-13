#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Rsync - Simple Rsync Frontend

=head1 DESCRIPTION

With this module you can sync 2 directories via the I<rsync> command.

=head1 DEPENDENCIES

=over 4

=item Expect

=back

=head1 SYNOPSIS

 use Rex::Commands::Rsync;
 
 sync "dir1", "dir2";

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Rsync;

use strict;
use warnings;

use Expect;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sync);


=item sync($source, $dest, $opts)

This function executes rsync to sync $source and $dest.

=over 4

=item UPLOAD - Will upload all from the local directory I<html> to the remote directory I</var/www/html>.

 task "sync", "server01", sub {
    sync "html/*", "/var/www/html", {
      exclude => "*.sw*",
      parameters => '--backup --delete',
    };
 };

 task "sync", "server01", sub {
    sync "html/*", "/var/www/html", {
      exclude => ["*.sw*", "*.tmp"],
      parameters => '--backup --delete',
    };
 };

=item DOWNLOAD - Will download all from the remote directory I</var/www/html> to the local directory I<html>.

 task "sync", "server01", sub {
    sync "/var/www/html/*", "html/", {
      download => 1,
      parameters => '--backup',
    };
 };

=back

=cut

sub sync {
   my ($source, $dest, $opt) = @_;

   my $current_connection = Rex::get_current_connection();
   my $cmd;

   if(! exists $opt->{download} && $source !~ m/^\//) {
      # relative path, calculate from module root

      my ($caller_package, $caller_file, $caller_line) = caller;
      my $module_path = Rex::get_module_path($caller_package);

      if($module_path) {
         $source = "$module_path/$source";
      }
   }

   my $params = "";
   if($opt && exists $opt->{'exclude'}) {
      my $excludes = $opt->{'exclude'};
      $excludes = [$excludes] unless ref($excludes) eq "ARRAY";
      for my $exclude (@$excludes) {
         $params .= " --exclude=" . $exclude;
      }
   }

   if($opt && exists $opt->{parameters}) {
      $params .= " " . $opt->{parameters};
   }

   if($opt && exists $opt->{'download'} && $opt->{'download'} == 1) {
      Rex::Logger::debug("Downloading $source -> $dest");
      $cmd = "rsync $params -a -e '\%s' --verbose --stats " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $source . " " . $dest;
   }
   else {
      Rex::Logger::debug("Uploading $source -> $dest");
      $cmd = "rsync $params -a -e '\%s' --verbose --stats $source " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $dest;
   }

   my $pass = Rex::Config->get_password;
   my @expect_options = ();

   if(Rex::Config->get_password_auth) {
      $cmd = sprintf($cmd, 'ssh -o StrictHostKeyChecking=no ');
      push(@expect_options, [
                              qr{Are you sure you want to continue connecting},
                              sub {
                                 Rex::Logger::debug("Accepting key..");
                                 my $fh = shift;
                                 $fh->send("yes\n");
                                 exp_continue;
                              }
                            ],
                            [
                              qr{password: $},
                              sub {
                                 Rex::Logger::debug("Want Password");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      
      );
   }
   else {
      $cmd = sprintf($cmd, 'ssh -i ' . Rex::Config->get_private_key . " -o StrictHostKeyChecking=no ");
      push(@expect_options, [
                              qr{Are you sure you want to continue connecting},
                              sub {
                                 Rex::Logger::debug("Accepting key..");
                                 my $fh = shift;
                                 $fh->send("yes\n");
                                 exp_continue;
                              }
                            ],
                            [
                              qr{Enter passphrase for key.*: $},
                              sub {
                                 Rex::Logger::debug("Want Passphrase");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      );
   }

   Rex::Logger::debug("cmd: $cmd");

   eval {
      my $exp = Expect->spawn($cmd) or die($!);

      eval {
         $exp->expect(Rex::Config->get_timeout, @expect_options, [
                                 qr{total size is \d+\s+speedup is },
                                 sub {
                                    Rex::Logger::debug("Finished transfer very fast");
                                    die;
                                 }
                             
                              ]);

         $exp->expect(undef, [
                           qr{total size is \d+\s+speedup is },
                           sub {
                              Rex::Logger::debug("Finished transfer");
                              exp_continue;
                           }
                        ]);

      };

      $exp->soft_close;
   };

   if($@) {
      Rex::Logger::info($@);
   }

}

=back

=cut

1;
