#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Cron - Simple Cron Management

=head1 DESCRIPTION

With this Module you can manage your cronjobs.

=head1 SYNOPSIS

 use Rex::Commands::Cron;
     
 cron add => "root", {
            minute => '5',
            hour   => '*',
            day_of_month    => '*',
            month => '*',
            day_of_week => '*',
         };
           
 cron list => "root";
      
 cron delete => "root", 3;

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Cron;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;

@EXPORT = qw(cron);

=item cron($action => $user, ...)

=cut

sub cron {

   my ($action, $user, $config) = @_;

   if($action eq "list") {
      my @lines = run "crontab -u $user -l";
      my @ret = ();

      for my $line (@lines) {
         if($line =~ m/^$/) { next; }
         if($line =~ m/^#/) { next; }
         if($line =~ m/^\s+#/) { next; }
         if($line =~ m/^\s*$/) { next; }

         my ($minute, $hour, $day_of_month, $month, $day_of_week, $cmd) = split(/\s+/, $line, 6);
         push(@ret, {
            minute       => $minute,
            hour         => $hour,
            day_of_month => $day_of_month,
            month        => $month,
            day_of_week  => $day_of_week,
         });
      }

      return @ret;
   }
   elsif($action eq "add") {
      my @lines = run "crontab -u $user -l";
      my $new_cron = "";

      push (@lines, $new_cron);
      my $fh = file_write "/tmp/cron.rex.tmp";
      $fh->write(join("\n", @lines));
      $fh->close;

      run "crontab -u /tmp/cron.rex.tmp";
      unlink "/tmp/cron.rex.tmp";
   }
   elsif($action eq "delete") {
      my @lines = run "crontab -u $user -l";

      my $fh = file_write "/tmp/cron.rex.tmp";
      $fh->write(join("\n", @lines));
      $fh->close;

      run "crontab -u /tmp/cron.rex.tmp";
      unlink "/tmp/cron.rex.tmp";
   }

}

