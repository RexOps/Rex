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

=cut

package Rex::Commands::Cron;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);
use Carp;

use Rex::Cron;
use Data::Dumper;

@EXPORT = qw(cron cron_entry);

=head2 cron_entry($name, %option)

Manage cron entries.

 cron_entry "reload-httpd",
   ensure       => "present",
   command      => "/etc/init.d/httpd restart",
   minute       => "1,5",
   hour         => "11,23",
   month        => "1,5",
   day_of_week  => "1,3",
   day_of_month => "1,3,5",
   user         => "root",
   on_change    => sub { say "cron added"; };
 
 # remove an entry
 cron_entry "reload-httpd",
   ensure       => "absent",
   command      => "/etc/init.d/httpd restart",
   minute       => "1,5",
   hour         => "11,23",
   month        => "1,5",
   day_of_week  => "1,3",
   day_of_month => "1,3,5",
   user         => "root",
   on_change    => sub { say "cron removed."; };

=cut

sub cron_entry {
  my ( $name, %option ) = @_;

  $option{ensure} ||= "present";
  confess "No 'user' given." if ( !exists $option{user} );

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "cron_entry", name => $name );

  my $changed = 0;
  my $ensure  = $option{ensure};

  if ( $option{ensure} eq "present" ) {
    Rex::Logger::debug("Creating new cron_entry: $name");
    my $user = $option{user};

    delete $option{user};
    delete $option{ensure};
    $changed = &cron( add => $user, \%option );
  }
  elsif ( $option{ensure} eq "absent" ) {
    Rex::Logger::debug("Removing cron_entry: $name");
    my $user = $option{user};

    my $c = Rex::Cron->create();
    %option = $c->_create_defaults(%option);

    my @crons = &cron( list => $user );
    my $i     = 0;
    my $cron_id;
    for my $cron (@crons) {
      if ( $cron->{minute} eq $option{minute}
        && $cron->{hour} eq $option{hour}
        && $cron->{month} eq $option{month}
        && $cron->{day_of_week} eq $option{day_of_week}
        && $cron->{day_of_month} eq $option{day_of_month}
        && $cron->{command} eq $option{command} )
      {
        # cron found
        $cron_id = $i;
        last;
      }
      $i++;
    }

    delete $option{user};
    delete $option{ensure};
    if ( defined $cron_id ) {
      &cron( delete => $user, $cron_id );
      $changed = 1;
    }
    else {
      Rex::Logger::debug("Cron $name not found.");
      Rex::Logger::debug( Dumper( \%option ) );
    }
  }

  if ($changed) {
    if ( exists $option{on_change} && ref $option{on_change} eq "CODE" ) {
      $option{on_change}->( $name, %option );
    }

    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Resource cron_entry status changed to $ensure."
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "cron_entry", name => $name );
}

=head2 cron($action => $user, ...)

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

This example will add a cronjob running on the 1st, 3rd and 5th day of January and May, but only when it's a Monday or Wednesday. On those days, the job will run when the hour is 11 or 23, and the minute is 1 or 5 (in other words at 11:01, 11:05, 23:01 and 23:05).

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

This example will delete the 4th cronjob. Counting starts with zero (0).

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

  my ( $action, $user, $config, @more ) = @_;

  my $c = Rex::Cron->create();
  $c->read_user_cron($user); # this must always be the first action

  if ( $action eq "list" ) {
    return $c->list_jobs;
  }

  elsif ( $action eq "add" ) {
    if ( $c->add( %{$config} ) ) {
      my $rnd_file = $c->write_cron;
      $c->activate_user_cron( $rnd_file, $user );
      return 1;              # something changed
    }
    return 0;                # nothing changed
  }

  elsif ( $action eq "delete" ) {
    my $to_delete = $config;
    $c->delete_job($to_delete);
    my $rnd_file = $c->write_cron;
    $c->activate_user_cron( $rnd_file, $user );
  }

  elsif ( $action eq "env" ) {
    my $env_action = $config;

    if ( $env_action eq "add" ) {
      my $data = shift @more;

      for my $key ( keys %{$data} ) {
        $c->add_env( $key => $data->{$key}, );
      }

      my $rnd_file = $c->write_cron;
      $c->activate_user_cron( $rnd_file, $user );
    }

    elsif ( $env_action eq "list" ) {
      return $c->list_envs;
    }

    elsif ( $env_action eq "delete" ) {
      my $num = shift @more;
      $c->delete_env($num);

      my $rnd_file = $c->write_cron;
      $c->activate_user_cron( $rnd_file, $user );
    }

  }

}

1;
