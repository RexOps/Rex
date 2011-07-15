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

With this function you can manage cronjobs.

List cronjobs.

 use Rex::Commands::Cron;
 use Data::Dumper;
    
 task "listcron", "server1", sub {
    my @crons = cron list => "root";
    print Dumper(\@crons);
 };

Add a cronjob.

This example will add a cronjob running on minute 1, 5, 19 and 40. Every hour and every day.

 use Rex::Commands::Cron;
 use Data::Dumper;
    
 task "addcron", "server1", sub {
     cron add => "root", {
        minute => "1,5,19,40",
     };
 };

This example will add a cronjob only running on the 1st, 3rd and 5th day of a month. But only when these days are monday or wednesday. And only in January and May. To the 11th and 23th hour. And to the 1st and 5th minute.

 task "addcron", "server1", sub {
     cron add => "root", {
        minute => "1,5",
        hour   => "11,23",
        month  => "1,5",
        day_of_week => "1,3",
        day_of_month => "1,3,5",
     };
 };

Delete a cronjob.

This example will delete the 4th cronjob. It starts counting by zero (0).

 task "delcron", "server1", sub {
     cron delete => "root", 3;
 };

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

         if(exists $config->{"as_text"}) {
            push(@ret, $line);
         }
         else {
            my ($minute, $hour, $day_of_month, $month, $day_of_week, $cmd) = split(/\s+/, $line, 6);
            push(@ret, {
               minute       => $minute,
               hour         => $hour,
               day_of_month => $day_of_month,
               month        => $month,
               day_of_week  => $day_of_week,
               command      => $cmd,
            });
         }
      }

      return @ret;
   }
   elsif($action eq "add") {
      my @lines = run "crontab -u $user -l";

      my $new_cron = sprintf("%s %s %s %s %s %s", $config->{"minute"} || "*",
                                                  $config->{"hour"} || "*",
                                                  $config->{"day_of_month"} || "*",
                                                  $config->{"month"} || "*",
                                                  $config->{"day_of_week"} || "*",
                                                  $config->{"command"} || "*",
                                                  );

      push (@lines, $new_cron);
      my $fh = file_write "/tmp/cron.rex.tmp";
      $fh->write(join("\n", @lines) . "\n");
      $fh->close;

      run "crontab -u $user /tmp/cron.rex.tmp";
      unlink "/tmp/cron.rex.tmp";
   }
   elsif($action eq "delete") {
      my @crons = cron(list => $user, {as_text => 1});

      splice(@crons, $config, 1);

      my $fh = file_write "/tmp/cron.rex.tmp";
      $fh->write(join("\n", @crons) . "\n");
      $fh->close;

      run "crontab -u $user /tmp/cron.rex.tmp";
      unlink "/tmp/cron.rex.tmp";
   }

}

=back

=cut

1;
