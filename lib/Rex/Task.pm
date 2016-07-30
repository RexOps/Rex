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

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw(time);

# VERSION

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

use Moose;
use MooseX::Aliases;

has name => ( is => 'ro', isa => 'Str' );
has func => (
  is      => 'ro',
  isa     => 'CodeRef',
  default => sub {
    sub { }
  }
);
alias code => 'func';

has server      => ( is => 'ro', isa => 'ArrayRef | Undef' );
has desc        => ( is => 'ro', isa => 'Str | Undef' );
has parallelism => ( is => 'rw', isa => 'Int', default => sub { 1 } );
has no_ssh      => ( is => 'ro', isa => 'Bool', default => sub { 0 } );
has hidden      => ( is => 'ro', isa => 'Bool | Undef', default => sub { 0 } );
has auth        => ( is => 'ro', isa => 'HashRef | Undef', default => sub { } );
has before_hooks =>
  ( is => 'ro', isa => 'ArrayRef[CodeRef] | Undef', default => sub { } );
has after_hooks =>
  ( is => 'ro', isa => 'ArrayRef[CodeRef] | Undef', default => sub { } );
has around_hooks =>
  ( is => 'ro', isa => 'ArrayRef[CodeRef] | Undef', default => sub { } );
has before_task_start_hooks =>
  ( is => 'ro', isa => 'ArrayRef[CodeRef] | Undef', default => sub { } );
has after_task_finished_hooks =>
  ( is => 'ro', isa => 'ArrayRef[CodeRef] | Undef', default => sub { } );
has app => ( is => 'ro', isa => 'Rex', default => sub { Rex->instance } );
has executor => (
  is      => 'ro',
  isa     => 'Rex::Interface::Executor::Base',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $exec = Rex::Interface::Executor->create(
      "Default",
      app  => $self->app,
      task => $self
    );
    return $exec;
  }
);
has opts => (
  is      => 'ro',
  isa     => 'HashRef | Undef',
  default => sub { {} },
  writer  => '_set_opts'
);
has args => (
  is      => 'ro',
  isa     => 'ArrayRef | Undef',
  default => sub { [] },
  writer  => '_set_args'
);
has connection => (
  is      => 'ro',
  isa     => 'Object | Undef',
  lazy    => 1,
  clearer => '_clear_connection',
  default => sub {
    my $self = shift;
    Rex::Interface::Connection->create( $self->get_connection_type );
  }
);
has exit_on_connect_fail => ( is => 'ro', isa => 'Bool', default => sub { 1 } );
has connection_type => ( is => 'ro', isa => 'Str', required => 0, );
has current_server => (
  is => 'ro',

  #isa     => 'Rex::Group::Entry::Server | Undef | Str',
  writer  => '_set_current_server',
  lazy    => 1,
  default => sub { "<local>" }
);

=head2 server

Returns the servers on which the task should be executed as an ArrayRef.

=cut

# TODO coerce server attribute to objects
#sub server {
#  my ($self) = @_;
#
#  my @server = @{ $self->{server} };
#  my @ret    = ();
#
#  if ( ref( $server[-1] ) eq "HASH" ) {
#    Rex::deprecated(
#      undef, "0.40",
#      "Defining extra credentials within the task creation is deprecated.",
#      "Please use set auth => task => 'taskname' instead."
#    );
#
#    # use extra defined credentials
#    my $data = pop(@server);
#    $self->set_auth( "user",     $data->{'user'} );
#    $self->set_auth( "password", $data->{'password'} );
#
#    if ( exists $data->{"private_key"} ) {
#      $self->set_auth( "private_key", $data->{"private_key"} );
#      $self->set_auth( "public_key",  $data->{"public_key"} );
#    }
#  }
#
#  if ( ref( $self->{server} ) eq "ARRAY"
#    && scalar( @{ $self->{server} } ) > 0 )
#  {
#    for my $srv ( @{ $self->{server} } ) {
#      if ( ref($srv) eq "CODE" ) {
#        push( @ret, &$srv() );
#      }
#      else {
#        if ( ref $srv && $srv->isa("Rex::Group::Entry::Server") ) {
#          push( @ret, $srv->get_servers );
#        }
#        else {
#          push( @ret, $srv );
#        }
#      }
#    }
#  }
#  elsif ( ref( $self->{server} ) eq "CODE" ) {
#    push( @ret, &{ $self->{server} }() );
#  }
#  else {
#    push( @ret, Rex::Group::Entry::Server->new( name => "<local>" ) );
#  }
#
#  return [@ret];
#}

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
    if ( $self->server && scalar( @{ $self->server } ) > 0 ) {
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
  return ( $self->connection_type && lc( $self->connection_type ) eq "http" );
}

=head2 is_https

Returns true (1) if the task gets executed over https protocol.

=cut

sub is_https {
  my ($self) = @_;
  return ( $self->connection_type && lc( $self->connection_type ) eq "https" );
}

=head2 is_openssh

Returns true (1) if the task gets executed with openssh.

=cut

sub is_openssh {
  my ($self) = @_;
  return ( $self->connection_type
      && lc( $self->connection_type ) eq "openssh" );
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

# TODO use Moose writer functions
#sub modify {
#  my ( $self, $key, $value ) = @_;
#
#  if ( ref( $self->{$key} ) eq "ARRAY" ) {
#    push( @{ $self->{$key} }, $value );
#  }
#  else {
#    $self->{$key} = $value;
#  }
#
#  $self->rethink_connection;
#}

=head2 rethink_connection

Deletes current connection object.

=cut

sub rethink_connection {
  my ($self) = @_;
  $self->_clear_connection;
}

=head2 user

Returns the username the task will use.

=cut

sub user {
  my ($self) = @_;
  if ( $self->auth && $self->auth->{user} ) {
    return $self->auth->{user};
  }
}

=head2 set_user($user)

Set the username of a task.

=cut

sub set_user {
  my ( $self, $user ) = @_;
  my $auth = $self->auth;
  $auth->{user} = $user;
  $self->_set_auth($auth);
}

=head2 password

Returns the password that will be used.

=cut

sub password {
  my ($self) = @_;
  if ( $self->auth && $self->auth->{password} ) {
    return $self->auth->{password};
  }
}

=head2 set_password($password)

Set the password of the task.

=cut

sub set_password {
  my ( $self, $password ) = @_;
  my $auth = $self->auth;
  $auth->{password} = $password;
  $self->_set_auth($auth);
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
    $self->_set_auth( {@_} );
  }
  else {
    my $auth = $self->auth;
    $auth->{$key} = $value;
    $self->_set_auth($auth);
  }
}

=head2 merge_auth($server)

Merges the authentication information from $server into the task.
Tasks authentication information have precedence.

=cut

sub merge_auth {
  my ( $self, $server ) = @_;

  # merge auth hashs
  # auth info of task has precedence
  my %auth = $server->merge_auth( $self->auth );

  return \%auth;
}

=head2 get_sudo_password

Returns the sudo password.

=cut

sub get_sudo_password {
  my ($self) = @_;

  my $server = $self->connection->server;
  my %auth   = $server->merge_auth( $self->auth );

  return $auth{sudo_password};
}

=head2 connect($server)

Initiate the connection to $server.

=cut

sub connect {
  my ( $self, $server, %override ) = @_;

  if ( !ref $server ) {
    $server = Rex::Group::Entry::Server->new( name => $server );
  }
  $self->_set_current_server($server);

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

  $self->run_hook( \$server, "before" );

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
      task     => [$self],
      profiler => $profiler,
      reporter => Rex::Report->create( Rex::Config->get_report_type ),
      notify   => Rex::Notify->new(),
    }
  );

  # TODO ist nach oben gewandert
  #  push @{ Rex::get_current_connection()->{task} }, $self;

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

  $self->_clear_connection;

  $self->run_hook( \$server, "after" );

  pop @{ Rex::get_current_connection()->{task} };

  # need to get rid of this
  Rex::pop_connection();
}

=head2 get_data

Dump task data.

=cut

sub get_data {
  my ($self) = @_;
  return {
    func            => $self->func,
    server          => $self->server,
    desc            => $self->desc,
    no_ssh          => $self->no_ssh,
    hidden          => $self->hidden,
    auth            => $self->auth,
    before_hooks    => $self->before_hooks,
    after_hooks     => $self->after_hooks,
    around_hooks    => $self->around_hooks,
    name            => $self->name,
    executor        => $self->executor,
    connection_type => $self->connection_type,
    opts            => $self->opts,
    args            => $self->args,
  };
}

=head2 run($server, %options)

Run the task on C<$server>, with C<%options>.

=cut

sub run {
  my ( $self, $server, %options ) = @_;

  $options{opts}   ||= $self->opts;
  $options{args}   ||= $self->args;
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
    push @{ Rex::get_current_connection()->{task} }, $self;
  }

  # execute code
  my @ret;
  my $wantarray = wantarray;

  eval {
    $self->_set_opts( $options{params} )
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

=head2 modify_task($task, $key => $value)

Modify C<$task>, by setting C<$key> to C<$value>.

=cut

#sub modify_task {
#  my $class = shift;
#  my $task  = shift;
#  my $key   = shift;
#  my $value = shift;
#
#  Rex::TaskList->create()->get_task($task)->modify( $key => $value );
#}

=head2 get_args

Returns arguments of task.

=cut

sub get_args {
  my ($self) = @_;
  @{ $self->args || [] };
}

=head2 get_opts

Returns options of task.

=cut

sub get_opts {
  my ($self) = @_;
  %{ $self->opts || {} };
}

=head2 set_args

Sets arguments for task.

=cut

sub set_args {
  my ( $self, @args ) = @_;
  $self->_set_args( \@args );
}

=head2 set_opt

Sets an option for task.

=cut

sub set_opt {
  my ( $self, $key, $value ) = @_;
  my $opts = $self->opts;
  $opts->{$key} = $value;
  $self->_set_opts($opts);
}

=head2 set_opts

Sets options for task.

=cut

sub set_opts {
  my ( $self, %opts ) = @_;
  $self->_set_opts( \%opts );
}

=head2 clone

Clones a task.

=cut

sub clone {
  my $self = shift;
  return Rex::Task->new( %{ $self->get_data } );
}

1;
