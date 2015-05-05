#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::TaskList::Base;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Task;
use Rex::Config;
use Rex::Interface::Executor;
use Rex::Fork::Manager;
use Rex::Report;
use Rex::Group;
use Time::HiRes qw(time);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{IN_TRANSACTION} = 0;
  $self->{DEFAULT_AUTH}   = 1;
  $self->{tasks}          = {};

  return $self;
}

sub create_task {
  my $self      = shift;
  my $task_name = shift;
  my $options   = pop;
  my $desc      = pop;

  if ( exists $self->{tasks}->{$task_name} ) {
    Rex::Logger::info( "Task $task_name already exists. Overwriting...",
      "warn" );
  }

  Rex::Logger::debug("Creating task: $task_name");

  my $func;
  if ( ref($desc) eq "CODE" ) {
    $func = $desc;
    $desc = "";
  }
  else {
    $func = pop;
  }

  my $requested_env = Rex::Config->get_environment;
  my @environments  = Rex::Commands->get_environments;

  if ( $task_name ne 'Commands:Box:get_sys_info'
    && $task_name ne 'Test:run'
    && $requested_env ne ''
    && !grep { $_ eq $requested_env } @environments )
  {
    Rex::Logger::info( "Environment '$requested_env' not defined.", 'error' );
    exit(1);
  }

  my @server = ();

  if ($::FORCE_SERVER) {

    if ( ref $::FORCE_SERVER eq "ARRAY" ) {
      my $group_name_arr = $::FORCE_SERVER;

      for my $group_name ( @{$group_name_arr} ) {
        if ( !Rex::Group->is_group($group_name) ) {
          Rex::Logger::debug("Using late group-lookup");

          push @server, sub {
            if ( !Rex::Group->is_group($group_name) ) {
              Rex::Logger::info( "No group $group_name defined.", "error" );
              exit 1;
            }

            return
              map { Rex::Group::Entry::Server->new( name => $_ )->get_servers; }
              Rex::Group->get_group($group_name);
          };
        }
        else {

          push( @server,
            map { Rex::Group::Entry::Server->new( name => $_ ); }
              Rex::Group->get_group($group_name) );

        }
      }
    }
    else {
      my @servers = split( /\s+/, $::FORCE_SERVER );
      push( @server,
        map { Rex::Group::Entry::Server->new( name => $_ ); } @servers );

      Rex::Logger::debug("\tserver: $_") for @server;
    }

  }

  else {

    if ( scalar(@_) >= 1 ) {
      if ( $_[0] eq "group" ) {
        my $groups;
        if ( ref( $_[1] ) eq "ARRAY" ) {
          $groups = $_[1];
        }
        else {
          $groups = [ $_[1] ];
        }

        for my $group ( @{$groups} ) {
          if ( Rex::Group->is_group($group) ) {
            my @group_server = Rex::Group->get_group($group);

            # check if the group is empty. this is mostly due to a failure.
            # so report it, and exit.
            if ( scalar @group_server == 0
              && Rex::Config->get_allow_empty_groups() == 0 )
            {
              Rex::Logger::info(
                "The group $group is empty. This is mostly due to a failure.",
                "warn" );
              Rex::Logger::info(
                "If this is an expected behaviour, please add the feature flag 'empty_groups'.",
                "warn"
              );
              CORE::exit(1);
            }
            push( @server, @group_server );
          }
          else {
            Rex::Logger::debug("Using late group-lookup");

            push @server, sub {
              if ( !Rex::Group->is_group($group) ) {
                Rex::Logger::info( "No group $group defined.", "error" );
                exit 1;
              }

              return map {
                Rex::Group::Entry::Server->new( name => $_ )->get_servers
              } Rex::Group->get_group($group);
            };

          }
        }
      }
      else {
        for my $entry (@_) {
          push(
            @server,
            (
              ref($entry) eq "Rex::Group::Entry"
              ? $entry
              : Rex::Group::Entry::Server->new( name => $entry )
            )
          );
        }
      }
    }

  }

  my %task_hash = (
    func                 => $func,
    server               => [@server],
    desc                 => $desc,
    no_ssh               => ( $options->{"no_ssh"} ? 1 : 0 ),
    hidden               => ( $options->{"dont_register"} ? 1 : 0 ),
    exit_on_connect_fail => (
      exists $options->{exit_on_connect_fail}
      ? $options->{exit_on_connect_fail}
      : 1
    ),
    before              => [],
    after               => [],
    around              => [],
    after_task_finished => [],
    before_task_start   => [],
    name                => $task_name,
    executor            => Rex::Interface::Executor->create,
    connection_type     => Rex::Config->get_connection_type,
  );

  if ( $self->{DEFAULT_AUTH} ) {
    $task_hash{auth} = {
      user          => Rex::Config->get_user          || undef,
      password      => Rex::Config->get_password      || undef,
      private_key   => Rex::Config->get_private_key   || undef,
      public_key    => Rex::Config->get_public_key    || undef,
      sudo_password => Rex::Config->get_sudo_password || undef,
    };
  }

  if ( exists $Rex::Commands::auth_late{$task_name} ) {
    $task_hash{auth} = $Rex::Commands::auth_late{$task_name};
  }

  $self->{tasks}->{$task_name} = Rex::Task->new(%task_hash);

}

sub get_tasks {
  my $self = shift;
  return grep { $self->{tasks}->{$_}->hidden() == 0 }
    sort      { $a cmp $b } keys %{ $self->{tasks} };
}

sub get_all_tasks {
  my $self   = shift;
  my $regexp = shift;

  return grep { $_ =~ $regexp }
    keys %{ $self->{tasks} };
}

sub get_tasks_for {
  my $self = shift;
  my $host = shift;

  my @tasks;
  for my $task_name ( keys %{ $self->{tasks} } ) {
    my @servers = @{ $self->{tasks}->{$task_name}->server() };

    if ( ( grep { /^$host$/ } @servers ) || $#servers == -1 ) {
      push @tasks, $task_name;
    }
  }

  my @ret = sort { $a cmp $b } @tasks;
  return @ret;
}

sub get_task {
  my ( $self, $task ) = @_;
  return $self->{tasks}->{$task};
}

sub clear_tasks {
  my $self = shift;
  $self->{tasks} = {};
}

sub get_desc {
  my $self = shift;
  my $task = shift;

  return $self->{tasks}->{$task}->desc();
}

sub is_task {
  my $self = shift;
  my $task = shift;

  if ( exists $self->{tasks}->{$task} ) { return 1; }
  return 0;
}

sub run {
  my ( $self, $task_name, %option ) = @_;
  my $task = $self->get_task($task_name);

  $option{params} ||= { Rex::Args->get };

  my @all_server = @{ $task->server };

  my $fm = Rex::Fork::Manager->new( max => $task->parallelism
      || Rex::Config->get_parallelism );

  for my $server (@all_server) {

    my $forked_sub = sub {

      Rex::Logger::init();

      # create a single task object for the run on $server

      Rex::Logger::info("Running task $task_name on $server");
      my $run_task = Rex::Task->new( %{ $task->get_data } );

      $run_task->run(
        $server,
        in_transaction => $self->{IN_TRANSACTION},
        params         => $option{params}
      );

      # destroy cached os info
      Rex::Logger::debug("Destroying all cached os information");

      Rex::Logger::shutdown();

    };

    # add the worker (forked_sub) to the fork queue
    unless ( $self->{IN_TRANSACTION} ) {

      # not inside a transaction, so lets fork happyly...
      $fm->add( $forked_sub, 1 );
    }
    else {
# inside a transaction, no little small funny kids, ... and no chance to get zombies :(
      &$forked_sub();
    }

  }

  Rex::Logger::debug("Waiting for children to finish");
  my $ret = $fm->wait_for_all;

  Rex::reconnect_lost_connections();

  return $ret;
}

sub modify {
  my ( $self, $type, $task, $code, $package, $file, $line ) = @_;

  return if defined $Rex::Test::Rexfile::Syntax::syntax_check;

  if ( $package ne "main" && $package ne "Rex::CLI" ) {
    if ( $task !~ m/:/ ) {

      #do we need to detect for base -Rex ?
      $package =~ s/^Rex:://;
      $package =~ s/::/:/g;
    }
  }

  my @all_tasks = map { $self->get_task($_); } grep {
    if ( $package ne "main" && $package ne "Rex::CLI" ) {
      $_ =~ m/^\Q$package\E:/;
    }
    else {
      $_ !~ m/:/;
    }
  } $self->get_all_tasks($task);

  if ( !@all_tasks ) {
    Rex::Logger::info(
      "Can't add $type $task, as it is not yet defined\nsee $file line $line");
    return;
  }

  for my $taskref (@all_tasks) {
    $taskref->modify( $type => $code );
  }
}

sub set_default_auth {
  my ( $self, $auth ) = @_;
  $self->{DEFAULT_AUTH} = $auth;
}

sub is_default_auth {
  my ($self) = @_;
  return $self->{DEFAULT_AUTH};
}

sub set_in_transaction {
  my ( $self, $val ) = @_;
  $self->{IN_TRANSACTION} = $val;
}

sub is_transaction {
  my ($self) = @_;
  return $self->{IN_TRANSACTION};
}

sub get_exit_codes {
  my ($self) = @_;
  return @Rex::Fork::Task::PROCESS_LIST;
}

1;
