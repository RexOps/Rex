#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Task - The Task Object

=head1 DESCRIPTION

The Task Object. Typically you only need this class if you want to manipulate tasks after their initial creation.

=head1 SYNOPSIS

 use Rex::Task;
 
 # create a new task
 my $task = Rex::Task->new(name => "testtask");
 $task->set_server("remoteserver");
 $task->set_code(sub { say "Hello"; });
 $task->modify("no_ssh", 1);
 
 # retrieve an existing task
 use Rex::TaskList;
 
 my $existing_task = Rex::TaskList->get_task('my_task');

=head1 METHODS

=cut

package Rex::Task;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw(time);

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::TaskList;
use Rex::Interface::Connection;
use Rex::Interface::Executor;
use Rex::Group::Entry::Server;
use Rex::Profiler;
use Rex::Hardware;
use Rex::Interface::Cache;
use Rex::Report;
use Rex::Helper::Run;
use Rex::Helper::Path;
use Rex::Notify;
use Carp;

require Rex::Commands;

require Rex::Args;

=head2 new

This is the constructor.

 $task = Rex::Task->new(
   func => sub { some_code_here },
   server => [ @server ],
   desc => $description,
   no_ssh => $no_ssh,
   hidden => $hidden,
   auth => {
     user      => $user,
     password   => $password,
     private_key => $private_key,
     public_key  => $public_key,
   },
   before => [sub {}, sub {}, ...],
   after  => [sub {}, sub {}, ...],
   around => [sub {}, sub {}, ...],
   before_task_start => [sub {}, sub {}, ...],
   after_task_finished => [sub {}, sub {}, ...],
   name => $task_name,
   executor => Rex::Interface::Executor->create,
   opts => {key1 => val1, key2 => val2, ...},
   args => [arg1, arg2, ...],
 );

=cut

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  if ( !exists $self->{name} ) {
    die("You have to define a task name.");
  }

  $self->{no_ssh}   ||= 0;
  $self->{func}     ||= sub { };
  $self->{executor} ||= Rex::Interface::Executor->create;
  $self->{opts}     ||= {};
  $self->{args}     ||= [];

  $self->{connection} = undef;

  # set to true as default
  if ( !exists $self->{exit_on_connect_fail} ) {
    $self->{exit_on_connect_fail} = 1;
  }

  return $self;
}

=head2 connection

Returns the current connection object.

=cut

sub connection {
  my ($self) = @_;
  if ( !exists $self->{connection} || !$self->{connection} ) {
    $self->{connection} =
      Rex::Interface::Connection->create( $self->get_connection_type );
  }

  $self->{connection};
}

sub set_connection {
  my ( $self, $conn ) = @_;
  $self->{connection} = $conn;
}

=head2 executor

Returns the current executor object.

=cut

sub executor {
  my ($self) = @_;
  $self->{executor}->set_task($self);
  return $self->{executor};
}

=head2 hidden

Returns true if the task is hidden. (Should not be displayed on ,,rex -T''.)

=cut

sub hidden {
  my ($self) = @_;
  return $self->{hidden};
}

=head2 server

Returns the servers on which the task should be executed as an ArrayRef.

=cut

sub server {
  my ($self) = @_;

  my @server = @{ $self->{server} };
  my @ret    = ();

  if ( ref( $server[-1] ) eq "HASH" ) {
    Rex::deprecated(
      undef, "0.40",
      "Defining extra credentials within the task creation is deprecated.",
      "Please use set auth => task => 'taskname' instead."
    );

    # use extra defined credentials
    my $data = pop(@server);
    $self->set_auth( "user",     $data->{'user'} );
    $self->set_auth( "password", $data->{'password'} );

    if ( exists $data->{"private_key"} ) {
      $self->set_auth( "private_key", $data->{"private_key"} );
      $self->set_auth( "public_key",  $data->{"public_key"} );
    }
  }

  if ( ref( $self->{server} ) eq "ARRAY"
    && scalar( @{ $self->{server} } ) > 0 )
  {
    for my $srv ( @{ $self->{server} } ) {
      if ( ref($srv) eq "CODE" ) {
        push( @ret, &$srv() );
      }
      else {
        if ( ref $srv && $srv->isa("Rex::Group::Entry::Server") ) {
          push( @ret, $srv->get_servers );
        }
        else {
          push( @ret, $srv );
        }
      }
    }
  }
  elsif ( ref( $self->{server} ) eq "CODE" ) {
    push( @ret, &{ $self->{server} }() );
  }
  else {
    push( @ret, Rex::Group::Entry::Server->new( name => "<local>" ) );
  }

  return [@ret];
}

=head2 set_server(@server)

With this method you can set new servers on which the task should be executed on.

=cut

sub set_server {
  my ( $self, @server ) = @_;
  $self->{server} = \@server;
}

=head2 delete_server

Delete every server registered to the task.

=cut

sub delete_server {
  my ($self) = @_;
  delete $self->{current_server};
  delete $self->{server};
  $self->rethink_connection;
}

=head2 current_server

Returns the current server on which the tasks gets executed right now.

=cut

sub current_server {
  my ($self) = @_;
  return $self->{current_server}
    || Rex::Group::Entry::Server->new( name => "<local>" );
}

=head2 desc

Returns the description of a task.

=cut

sub desc {
  my ($self) = @_;
  return $self->{desc};
}

=head2 set_desc($description)

Set the description of a task.

=cut

sub set_desc {
  my ( $self, $desc ) = @_;
  $self->{desc} = $desc;
}

=head2 is_remote

Returns true (1) if the task will be executed remotely.

=cut

sub is_remote {
  my ($self) = @_;
  if ( exists $self->{current_server} ) {
    if ( $self->{current_server} ne '<local>' ) {
      return 1;
    }
  }
  else {
    if ( exists $self->{server} && scalar( @{ $self->{server} } ) > 0 ) {
      return 1;
    }
  }

  return 0;
}

=head2 is_local

Returns true (1) if the task gets executed on the local host.

=cut

sub is_local {
  my ($self) = @_;
  return $self->is_remote() == 0 ? 1 : 0;
}

=head2 is_http

Returns true (1) if the task gets executed over http protocol.

=cut

sub is_http {
  my ($self) = @_;
  return ( $self->{"connection_type"}
      && lc( $self->{"connection_type"} ) eq "http" );
}

=head2 is_https

Returns true (1) if the task gets executed over https protocol.

=cut

sub is_https {
  my ($self) = @_;
  return ( $self->{"connection_type"}
      && lc( $self->{"connection_type"} ) eq "https" );
}

=head2 is_openssh

Returns true (1) if the task gets executed with openssh.

=cut

sub is_openssh {
  my ($self) = @_;
  return ( $self->{"connection_type"}
      && lc( $self->{"connection_type"} ) eq "openssh" );
}

=head2 want_connect

Returns true (1) if the task will establish a connection to a remote system.

=cut

sub want_connect {
  my ($self) = @_;
  return $self->{no_ssh} == 0 ? 1 : 0;
}

=head2 get_connection_type

This method tries to guess the right connection type for the task and returns it.

Current return values are below:

=over 4

=item * SSH: connect to the remote server using Net::SSH2

=item * OpenSSH: connect to the remote server using Net::OpenSSH

=item * Local: runs locally (without any connections)

=item * HTTP: uses experimental HTTP connection

=item * HTTPS: uses experimental HTTPS connection

=item * Fake: populate the connection properties, but do not connect

So you can use this type to iterate over a list of remote hosts, but don't let rex build a connection. For example if you want to use Sys::Virt or other modules.

=back

=cut

sub get_connection_type {
  my ($self) = @_;

  if ( $self->is_http ) {
    return "HTTP";
  }
  elsif ( $self->is_https ) {
    return "HTTPS";
  }
  elsif ( $self->is_remote && $self->is_openssh && $self->want_connect ) {
    return "OpenSSH";
  }
  elsif ( $self->is_remote && $self->want_connect ) {
    return Rex::Config->get_connection_type();
  }
  elsif ( $self->is_remote ) {
    return "Fake";
  }
  else {
    return "Local";
  }
}

=head2 modify($key, $value)

With this method you can modify values of the task.

=cut

sub modify {
  my ( $self, $key, $value ) = @_;

  if ( ref( $self->{$key} ) eq "ARRAY" ) {
    push( @{ $self->{$key} }, $value );
  }
  else {
    $self->{$key} = $value;
  }

  $self->rethink_connection;
}

=head2 rethink_connection

Deletes current connection object.

=cut

sub rethink_connection {
  my ($self) = @_;
  delete $self->{connection};
}

=head2 user

Returns the username the task will use.

=cut

sub user {
  my ($self) = @_;
  if ( exists $self->{auth} && $self->{auth}->{user} ) {
    return $self->{auth}->{user};
  }
}

=head2 set_user($user)

Set the username of a task.

=cut

sub set_user {
  my ( $self, $user ) = @_;
  $self->{auth}->{user} = $user;
}

=head2 password

Returns the password that will be used.

=cut

sub password {
  my ($self) = @_;
  if ( exists $self->{auth} && $self->{auth}->{password} ) {
    return $self->{auth}->{password};
  }
}

=head2 set_password($password)

Set the password of the task.

=cut

sub set_password {
  my ( $self, $password ) = @_;
  $self->{auth}->{password} = $password;
}

=head2 name

Returns the name of the task.

=cut

sub name {
  my ($self) = @_;
  return $self->{name};
}

=head2 code

Returns the code of the task.

=cut

sub code {
  my ($self) = @_;
  return $self->{func};
}

=head2 set_code(\&code_ref)

Set the code of the task.

=cut

sub set_code {
  my ( $self, $code ) = @_;
  $self->{func} = $code;
}

=head2 run_hook($server, $hook)

This method is used internally to execute the specified hooks.

=cut

sub run_hook {
  my ( $self, $server, $hook, @more_args ) = @_;
  my $old_server;

  for my $code ( @{ $self->{$hook} } ) {
    if ( $hook eq "after" ) { # special case for after hooks
      $code->(
        $$server,
        ( $self->{"__was_authenticated"} || 0 ),
        { $self->get_opts }, @more_args
      );
    }
    else {
      $old_server = $$server if $server;
      $code->( $$server, $server, { $self->get_opts }, @more_args );
      if ( $old_server && $old_server ne $$server ) {
        $self->{current_server} = $$server;
      }
    }
  }
}

=head2 set_auth($key, $value)

Set the authentication of the task.

 $task->set_auth("user", "foo");
 $task->set_auth("password", "bar");

=cut

sub set_auth {
  my ( $self, $key, $value ) = @_;

  if ( scalar(@_) > 3 ) {
    my $_d = shift;
    $self->{auth} = {@_};
  }
  else {
    $self->{auth}->{$key} = $value;
  }
}

=head2 merge_auth($server)

Merges the authentication information from $server into the task.
Tasks authentication information have precedence.

=cut

sub merge_auth {
  my ( $self, $server ) = @_;

  # merge auth hashs
  # task auth as precedence
  my %auth = $server->merge_auth( $self->{auth} );

  return \%auth;
}

=head2 get_sudo_password

Returns the sudo password.

=cut

sub get_sudo_password {
  my ($self) = @_;

  my $server = $self->connection->server;
  my %auth   = $server->merge_auth( $self->{auth} );

  return $auth{sudo_password};
}

=head2 parallelism

Get the parallelism count of a task.

=cut

sub parallelism {
  my ($self) = @_;
  return $self->{parallelism};
}

=head2 set_parallelism($count)

Set the parallelism of the task.

=cut

sub set_parallelism {
  my ( $self, $para ) = @_;
  $self->{parallelism} = $para;
}

=head2 connect($server)

Initiate the connection to $server.

=cut

sub connect {
  my ( $self, $server, %override ) = @_;

  if ( !ref $server ) {
    $server = Rex::Group::Entry::Server->new( name => $server );
  }
  $self->{current_server} = $server;

  $self->run_hook( \$server, "before" );

  # need to be called, in case of a run_task task call.
  # see #788
  $self->rethink_connection;

  my $user = $self->user;

  #print Dumper($self);
  my $auth = $self->merge_auth($server);

  if ( exists $override{auth} ) {
    $auth = $override{auth};
    $user = $auth->{user};
  }

  my $rex_int_conf = Rex::Commands::get("rex_internals");
  Rex::Logger::debug( Dumper($rex_int_conf) );
  Rex::Logger::debug("Auth-Information inside Task:");
  for my $key ( keys %{$auth} ) {
    my $data = $auth->{$key};
    $data = Rex::Logger::masq( "%s", $data ) if $key eq 'password';
    $data = Rex::Logger::masq( "%s", $data ) if $key eq 'sudo_password';
    $data ||= "";

    Rex::Logger::debug("$key => [[$data]]");
  }

  $auth->{public_key} = resolv_path( $auth->{public_key}, 1 )
    if ( $auth->{public_key} );
  $auth->{private_key} = resolv_path( $auth->{private_key}, 1 )
    if ( $auth->{private_key} );

  my $profiler = Rex::Profiler->new;

  # task specific auth rules over all
  my %connect_hash = %{$auth};
  $connect_hash{server} = $server;

  # need to get rid of this
  Rex::push_connection(
    {
      conn     => $self->connection,
      ssh      => $self->connection->get_connection_object,
      server   => $server,
      cache    => Rex::Interface::Cache->create(),
      task     => [],
      profiler => $profiler,
      reporter => Rex::Report->create( Rex::Config->get_report_type ),
      notify   => Rex::Notify->new(),
    }
  );

  push @{ Rex::get_current_connection()->{task} }, $self;

  $profiler->start("connect");
  eval {
    $self->connection->connect(%connect_hash);
    1;
  } or do {
    if ( !defined Rex::Config->get_fallback_auth ) {
      croak $@;
    }
  };
  $profiler->end("connect");

  if ( !$self->connection->is_connected ) {
    Rex::pop_connection();
    croak("Couldn't connect to $server.");
  }
  elsif ( !$self->connection->is_authenticated ) {
    Rex::pop_connection();
    my $message =
      "Couldn't authenticate against $server. It may be caused by one or more of:\n";
    $message .= " - wrong username, password, key or passphrase\n";
    $message .= " - changed remote host key\n";
    $message .= " - root is not permitted to login over SSH\n"
      if ( $connect_hash{user} eq 'root' );

    if ( !exists $override{auth} ) {
      my $fallback_auth = Rex::Config->get_fallback_auth;
      if ( ref $fallback_auth eq "ARRAY" ) {
        my $ret_eval;
        for my $fallback_a ( @{$fallback_auth} ) {
          $ret_eval = eval { $self->connect( $server, auth => $fallback_a ); };
        }

        return $ret_eval if $ret_eval;
      }
    }

    croak($message);
  }
  else {
    Rex::Logger::debug("Successfully authenticated on $server.")
      if ( $self->connection->get_connection_type ne "Local" );
    $self->{"__was_authenticated"} = 1;
  }

  $self->run_hook( \$server, "around" );

  return 1;
}

=head2 disconnect

Disconnect from the current connection.

=cut

sub disconnect {
  my ( $self, $server ) = @_;

  $self->run_hook( \$server, "around", 1 );
  $self->connection->disconnect;

  my %args = Rex::Args->getopts;

  if ( defined $args{'d'} && $args{'d'} > 2 ) {
    Rex::Commands::profiler()->report;
  }

  delete $self->{connection};

  pop @{ Rex::get_current_connection()->{task} };

  # need to get rid of this
  Rex::pop_connection();

  $self->run_hook( \$server, "after" );
}

=head2 get_data

Dump task data.

=cut

sub get_data {
  my ($self) = @_;

  return {
    func            => $self->{func},
    server          => $self->{server},
    desc            => $self->{desc},
    no_ssh          => $self->{no_ssh},
    hidden          => $self->{hidden},
    auth            => $self->{auth},
    before          => $self->{before},
    after           => $self->{after},
    around          => $self->{around},
    name            => $self->{name},
    executor        => $self->{executor},
    connection_type => $self->{connection_type},
    opts            => $self->{opts},
    args            => $self->{args},
  };
}

=head2 run($server, %options)

Run the task on C<$server>, with C<%options>.

=cut

sub run {
  return pre_40_run(@_) unless ref $_[0];

  my ( $self, $server, %options ) = @_;

  $options{opts}   ||= { $self->get_opts };
  $options{args}   ||= [ $self->get_args ];
  $options{params} ||= $options{opts};

  if ( !ref $server ) {
    $server = Rex::Group::Entry::Server->new( name => $server );
  }

  if ( !$_[1] ) {

    # run is called without any server.
    # so just connect to any servers.
    return Rex::TaskList->create()->run( $self, %options );
  }

  # this is a method call
  # so run the task

  # TODO: refactor complete task calling
  #       direct call with function and normal task call

  my ( $in_transaction, $start_time );

  $start_time = time;

  if ( $server ne "<func>" ) {

    # this is _not_ a task call via function syntax.

    $in_transaction = $options{in_transaction};

    eval { $self->connect($server) };
    if ($@) {
      my $error = $@;
      $self->{"__was_authenticated"} = 0;
      $self->run_hook( \$server, "after" );
      die $error;
    }

    if ( Rex::Args->is_opt("c") ) {

      # get and cache all os info
      if ( !Rex::get_cache()->load() ) {
        Rex::Logger::debug("No cache found, need to collect new data.");
        $server->gather_information;
      }
    }

    if ( !$server->test_perl ) {
      Rex::Logger::info(
        "There is no perl interpreter found on this system. "
          . "Some commands may not work. Sudo won't work.",
        "warn"
      );
      sleep 3;
    }

  }
  else {
# we need to push the connection information of the last task onto this task object
# if we don't do this, the task doesn't have any information of the current connection when called like a function.
# See: #1091
    $self->set_connection(
      Rex::get_current_connection()->{task}->[-1]->connection )
      if Rex::get_current_connection()->{task}->[-1];
    push @{ Rex::get_current_connection()->{task} }, $self;
  }

  # execute code
  my @ret;
  my $wantarray = wantarray;

  eval {
    $self->set_opts( %{ $options{params} } )
      if ref $options{params} eq "HASH";
    if ($wantarray) {
      @ret = $self->executor->exec( $options{params}, $options{args} );
    }
    else {
      $ret[0] = $self->executor->exec( $options{params}, $options{args} );
    }
    my $notify = Rex::get_current_connection()->{notify};
    $notify->run_postponed();
  } or do {
    if ($@) {
      my $error = $@;

      Rex::get_current_connection()->{reporter}
        ->report_resource_failed( message => $error );

      Rex::get_current_connection()->{reporter}->report_task_execution(
        failed     => 1,
        start_time => $start_time,
        end_time   => time,
        message    => $error,
      );

      Rex::get_current_connection()->{reporter}->write_report();

      pop @{ Rex::get_current_connection()->{task} };
      die($error);
    }
  };

  if ( $server ne "<func>" ) {
    if ( Rex::Args->is_opt("c") ) {

      # get and cache all os info
      Rex::get_cache()->save();
    }

    Rex::get_current_connection()->{reporter}->report_task_execution(
      failed     => 0,
      start_time => $start_time,
      end_time   => time,
    );

    Rex::get_current_connection()->{reporter}->write_report();

    if ($in_transaction) {
      $self->run_hook( \$server, "around", 1 );
      $self->run_hook( \$server, "after" );
    }
    else {
      $self->disconnect($server);
    }
  }
  else {
    pop @{ Rex::get_current_connection()->{task} };
  }

  if ($wantarray) {
    return @ret;
  }
  else {
    return $ret[0];
  }
}

sub pre_40_run {
  my ( $class, $task_name, $server_overwrite, $params ) = @_;

  # static calls to this method are deprecated
  Rex::deprecated( "Rex::Task->run()", "0.40" );

  my $tasklist = Rex::TaskList->create;
  my $task     = $tasklist->get_task($task_name);

  $task->set_server($server_overwrite) if $server_overwrite;
  $tasklist->run( $task, params => $params );
}

=head2 modify_task($task, $key => $value)

Modify C<$task>, by setting C<$key> to C<$value>.

=cut

sub modify_task {
  my $class = shift;
  my $task  = shift;
  my $key   = shift;
  my $value = shift;

  Rex::TaskList->create()->get_task($task)->modify( $key => $value );
}

=head2 is_task

Returns true(1) if the passed object is a task.

=cut

sub is_task {
  my ( $class, $task ) = @_;
  return Rex::TaskList->create()->is_task($task);
}

=head2 get_tasks

Returns list of tasks.

=cut

sub get_tasks {
  my ( $class, @tmp ) = @_;
  return Rex::TaskList->create()->get_tasks(@tmp);
}

=head2 get_desc

Returns description of task.

=cut

sub get_desc {
  my ( $class, @tmp ) = @_;
  return Rex::TaskList->create()->get_desc(@tmp);
}

=head2 exit_on_connect_fail

Returns true if rex should exit on connect failure.

=cut

sub exit_on_connect_fail {
  my ($self) = @_;
  return $self->{exit_on_connect_fail};
}

=head2 set_exit_on_connect_fail

Sets if rex should exit on connect failure.

=cut

sub set_exit_on_connect_fail {
  my ( $self, $exit ) = @_;
  $self->{exit_on_connect_fail} = $exit;
}

=head2 get_args

Returns arguments of task.

=cut

sub get_args {
  my ($self) = @_;
  @{ $self->{args} || [] };
}

=head2 get_opts

Returns options of task.

=cut

sub get_opts {
  my ($self) = @_;
  %{ $self->{opts} || {} };
}

=head2 set_args

Sets arguments for task.

=cut

sub set_args {
  my ( $self, @args ) = @_;
  $self->{args} = \@args;
}

=head2 set_opt

Sets an option for task.

=cut

sub set_opt {
  my ( $self, $key, $value ) = @_;
  $self->{opts}->{$key} = $value;
}

=head2 set_opts

Sets options for task.

=cut

sub set_opts {
  my ( $self, %opts ) = @_;
  $self->{opts} = \%opts;
}

=head2 clone

Clones a task.

=cut

sub clone {
  my $self = shift;
  return Rex::Task->new( %{ $self->get_data } );
}

1;
