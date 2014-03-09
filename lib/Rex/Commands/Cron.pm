#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Cron - Simple Cron Management

=head1 DESCRIPTION

With this Module you can manage your cronjobs.

=head1 SYNOPSIS

 use Rex::Commands::Cron;
    
 cron add => "root", {
        minute => '5',
        hour  => '*',
        day_of_month   => '*',
        month => '*',
        day_of_week => '*',
        command => '/path/to/your/cronjob',
      };
        
 cron list => "root";
    
 cron delete => "root", 3;

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Cron;

use strict;
use warnings;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Rex::Cron;

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
      command => '/path/to/your/cronjob',
    };
 };

This example will add a cronjob only running on the 1st, 3rd and 5th day of a month. But only when these days are monday or wednesday. And only in January and May. To the 11th and 23th hour. And to the 1st and 5th minute.

 task "addcron", "server1", sub {
    cron add => "root", {
      minute => "1,5",
      hour  => "11,23",
      month  => "1,5",
      day_of_week => "1,3",
      day_of_month => "1,3,5",
      command => '/path/to/your/cronjob',
    };
 };

Delete a cronjob.

This example will delete the 4th cronjob. It starts counting by zero (0).

 task "delcron", "server1", sub {
    cron delete => "root", 3;
 };

Managing Environment Variables inside cron.

 task "mycron", "server1", sub {
    cron env => user => add => {
      MYVAR => "foo",
    };
      
    cron env => user => delete => $index;
    cron env => user => delete => 1;
    
    cron env => user => "list";
 };

=cut

sub cron {

  my ($action, $user, $config, @more) = @_;

  my $c = Rex::Cron->create();
  $c->read_user_cron($user); # this must always be the first action

  if($action eq "list") {
    return $c->list_jobs;
  }

  elsif($action eq "add") {
    if($c->add(%{ $config })) {
      my $rnd_file = $c->write_cron;
      $c->activate_user_cron($rnd_file, $user);
    }
  }

  elsif($action eq "delete") {
    my $to_delete = $config;
    $c->delete_job($to_delete);
    my $rnd_file = $c->write_cron;
    $c->activate_user_cron($rnd_file, $user);
  }

  elsif($action eq "env") {
    my $env_action = $config;

    if($env_action eq "add") {
      my $data = shift @more;

      for my $key (keys %{ $data }) {
        $c->add_env(
          $key => $data->{$key},
        );
      }

      my $rnd_file = $c->write_cron;
      $c->activate_user_cron($rnd_file, $user);
    }

    elsif($env_action eq "list") {
      return $c->list_envs;
    }

    elsif($env_action eq "delete") {
      my $num = shift @more;
      $c->delete_env($num);

      my $rnd_file = $c->write_cron;
      $c->activate_user_cron($rnd_file, $user);
    }

  }

}

=back

=cut

1;
