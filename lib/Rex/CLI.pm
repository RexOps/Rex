#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CLI;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use FindBin;
use File::Basename qw(basename dirname);
use Time::HiRes qw(gettimeofday tv_interval);
use Cwd qw(getcwd);
use List::Util qw(max);
use Text::Wrap;
use Term::ReadKey;
use Sort::Naturally;

use Rex;
use Rex::Args;
use Rex::Config;
use Rex::Group;
use Rex::Batch;
use Rex::TaskList;
use Rex::Logger;
use YAML;

use Data::Dumper;

my $no_color = 0;
eval "use Term::ANSIColor";
if ($@) { $no_color = 1; }

if ( $^O =~ m/MSWin/ ) {
  eval "use Win32::Console::ANSI";
  if ($@) { $no_color = 1; }
}

# preload some modules
use Rex -base;

$|++;

my ( %opts, @help, @exit );

if ( $#ARGV < 0 ) {
  @ARGV = qw(-h);
}

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub __run__ {
  my ( $self, %more_args ) = @_;

  Rex::Args->parse_rex_opts;
  %opts = Rex::Args->getopts;

  if ( $opts{'Q'} ) {
    my ( $stdout, $stderr );
    open( my $newout, '>', \$stdout );
    select $newout;
    close(STDERR);
  }

  if ( $opts{'m'} ) {
    $no_color              = 1;
    $Rex::Logger::no_color = 1;
  }

  if ( $opts{'d'} ) {
    $Rex::Logger::debug  = $opts{'d'};
    $Rex::Logger::silent = 0;
  }

  Rex::Config->set_use_cache(1);
  if ( $opts{"c"} ) {

    #  Rex::Config->set_use_cache(1);
    # since 0.46 just a pseudo option
    # cache is enabled by default
  }
  elsif ( $opts{"C"} ) {
    Rex::Config->set_use_cache(0);
  }

  Rex::Logger::debug("This is Rex version: $Rex::VERSION");
  Rex::Logger::debug("Command Line Parameters");
  for my $param ( keys %opts ) {
    Rex::Logger::debug( "\t$param = " . $opts{$param} );
  }

  if ( $opts{'h'} ) {
    $self->__help__;
  }
  elsif ( $opts{'v'} && !$opts{'T'} ) {
    $self->__version__;
  }

  if ( $opts{'q'} ) {
    $::QUIET = 1;
    if ( $opts{'w'} ) {
      $::QUIET = 2;
    }
  }

  $::rexfile = "Rexfile";
  if ( $opts{'f'} ) {
    Rex::Logger::debug( "Using Rexfile: " . $opts{'f'} );
    $::rexfile = $opts{'f'};
  }
  else {
    if ( ( !-e $::rexfile ) && ( $ARGV[0] && $ARGV[0] =~ /:/ ) ) {

#if there is no Rexfile, and the user asks for a longer path task, see if we can use it as the Rexfile
#eg: rex -H $host Misc:Example:prepare --bar=baz
      $::rexfile = $ARGV[0];
      $::rexfile =~ s/:[^:]*$//;
      $::rexfile =~ s{:}{/}g;
      $::rexfile = 'Rex/' . $::rexfile . '.pm';
    }
  }

FORCE_SERVER: {

    if ( $opts{'H'} ) {
      if ( $opts{'H'} =~ m/^perl:(.*)/ ) {
        my $host_eval = eval($1);

        if ( ref($host_eval) eq "ARRAY" ) {
          $::FORCE_SERVER = join( " ", @{$host_eval} );
        }
        else {
          die("Perl Code have to return an array reference.");
        }
      }
      else {
        $::FORCE_SERVER = $opts{'H'};
      }
    }

  }

  if ( $opts{'z'} ) {
    my $host_eval = eval { `$opts{'z'}`; };
    if ( $host_eval =~ m/\S/xms ) {
      $::FORCE_SERVER = join( " ", split /\n|,|;/, $host_eval );
    }
    else {
      $::FORCE_SERVER = $opts{'H'};
    }
  }

  if ( $opts{'z'} ) {
    my $host_eval = eval { `$opts{'z'}`; };
    if ( $host_eval =~ m/\S/xms ) {
      $::FORCE_SERVER = join( " ", split /\n|,|;/, $host_eval );
    }
    else {
      Rex::Logger::info("You must give a valid command.");
    }
  }

  if ( $opts{'o'} ) {
    Rex::Output->require;
    Rex::Output->get( $opts{'o'} );
  }

  handle_lock_file($::rexfile);

  Rex::Config->set_environment( $opts{"E"} ) if ( $opts{"E"} );

  if ( $opts{'g'} || $opts{'G'} ) {

    #$::FORCE_SERVER = "\0" . $opts{'g'};
    $opts{'g'} ||= $opts{'G'};

    if ( ref $opts{'g'} ne "ARRAY" ) {
      $::FORCE_SERVER = [ $opts{'g'} ];
    }
    else {
      $::FORCE_SERVER = $opts{'g'};
    }
  }

  load_server_ini_file($::rexfile);
  load_rexfile($::rexfile);

  #### check if some parameters should be overwritten from the command line
CHECK_OVERWRITE: {

    my $pass_auth = 0;

    if ( $opts{'u'} ) {
      Rex::Commands::user( $opts{'u'} );
      for my $task ( Rex::TaskList->create()->get_tasks ) {
        Rex::TaskList->create()->get_task($task)->set_user( $opts{'u'} );
      }
    }

    if ( $opts{'p'} ) {
      Rex::Commands::password( $opts{'p'} );

      unless ( $opts{'P'} ) {
        $pass_auth = 1;
      }

      for my $task ( Rex::TaskList->create()->get_tasks ) {
        Rex::TaskList->create()->get_task($task)->set_password( $opts{'p'} );
      }

    }

    if ( $opts{'P'} ) {
      Rex::Commands::private_key( $opts{'P'} );

      for my $task ( Rex::TaskList->create()->get_tasks ) {
        Rex::TaskList->create()->get_task($task)
          ->set_auth( "private_key", $opts{'P'} );
      }
    }

    if ( $opts{'K'} ) {
      Rex::Commands::public_key( $opts{'K'} );

      for my $task ( Rex::TaskList->create()->get_tasks ) {
        Rex::TaskList->create()->get_task($task)
          ->set_auth( "public_key", $opts{'K'} );
      }
    }

    if ($pass_auth) {
      pass_auth;
    }

  }

  Rex::Logger::debug("Initializing Logger from parameters found in $::rexfile");

  if ( $opts{'T'} && $opts{'m'} ) {

    # create machine readable tasklist
    my @tasks = Rex::TaskList->create()->get_tasks;
    for my $task (@tasks) {
      my $desc = Rex::TaskList->create()->get_desc($task);
      $desc =~ s/'/\\'/gms;
      print "'$task'" . " = '$desc'\n";
    }
  }
  elsif ( $opts{'T'} && $opts{'y'} ) {
    my @tasks  = Rex::TaskList->create()->get_tasks;
    my @envs   = Rex::Commands->get_environments();
    my %groups = Rex::Group->get_groups;

    my %real_groups;

    for my $group ( keys %groups ) {
      my @servers = map { $_->get_servers }
        Rex::Group->get_group_object($group)->get_servers;
      $real_groups{$group} = \@servers;
    }

    print YAML::Dump(
      {
        tasks  => \@tasks,
        envs   => \@envs,
        groups => \%real_groups,
      }
    );
  }
  elsif ( $opts{'T'} ) {
    _handle_T(%opts);

    Rex::global_sudo(0);
    Rex::Logger::debug("Removing lockfile") if ( !exists $opts{'F'} );
    CORE::unlink("$::rexfile.lock")         if ( !exists $opts{'F'} );
    CORE::exit 0;
  }

  # turn sudo on with cli option s is used
  if ( exists $opts{'s'} ) {
    sudo("on");
  }
  if ( exists $opts{'S'} ) {
    sudo_password( $opts{'S'} );
  }

  if ( exists $opts{'t'} ) {
    parallelism( $opts{'t'} );
  }

  if ( $opts{'e'} ) {
    Rex::Logger::debug("Executing command line code");
    Rex::Logger::debug( "\t" . $opts{'e'} );

    # execute the given code
    my $code = "sub { \n";
    $code .= $opts{'e'} . "\n";
    $code .= "}";

    $code = eval($code);

    if ($@) {
      Rex::Logger::info( "Error in eval line: $@\n", "warn" );
      exit 1;
    }

    if ( exists $opts{'t'} ) {
      parallelism( $opts{'t'} );
    }

    my $pass_auth = 0;

    if ( $opts{'u'} ) {
      Rex::Commands::user( $opts{'u'} );
    }

    if ( $opts{'p'} ) {
      Rex::Commands::password( $opts{'p'} );

      unless ( $opts{'P'} ) {
        $pass_auth = 1;
      }
    }

    if ( $opts{'P'} ) {
      Rex::Commands::private_key( $opts{'P'} );
    }

    if ( $opts{'K'} ) {
      Rex::Commands::public_key( $opts{'K'} );
    }

    if ($pass_auth) {
      pass_auth;
    }

    my @params = ();
    if ( $opts{'H'} ) {
      push @params, split( /\s+/, $opts{'H'} );
    }
    push @params, $code;
    push @params, "eval-line-desc";
    push @params, {};

    Rex::TaskList->create()->create_task( "eval-line", @params );
    Rex::Commands::do_task("eval-line");
    exit_rex();
  }
  elsif ( $opts{'M'} ) {
    Rex::Logger::debug( "Loading Rex-Module: " . $opts{'M'} );
    my $mod = $opts{'M'};
    $mod =~ s{::}{/}g;
    $mod .= ".pm";
    require $mod;
  }

  my $run_list = Rex::RunList->instance;

  if ( $opts{'b'} ) {
    my $batch = $opts{'b'};
    Rex::Logger::debug("Running batch: $batch");
    $run_list->add_task($_) for Rex::Batch->get_batch($batch);
  }

  $run_list->parse_opts(@ARGV);

  eval { $run_list->run_tasks };
  if ($@) {

    # this is always the child
    Rex::Logger::info( "Error running task/batch: $@", "warn" );
    CORE::exit(0);
  }

  exit_rex();
}

sub _print_color {
  my ( $msg, $color ) = @_;
  $color = 'green' if !defined($color);

  if ($no_color) {
    print $msg;
  }
  else {
    print colored( [$color], $msg );
  }
}

sub __help__ {

  my $fmt = "  %-6s %s\n";

  print "usage: \n";
  print "  rex [<options>] [-H <host>] [-G <group>] <task> [<task-options>]\n";
  print "  rex -T[m|y|v] [<string>]\n";
  print "\n";
  printf $fmt, "-b",    "Run batch";
  printf $fmt, "-e",    "Run the given code fragment";
  printf $fmt, "-E",    "Execute a task on the given environment";
  printf $fmt, "-G|-g", "Execute a task on the given server groups";
  printf $fmt, "-H",    "Execute a task on the given hosts (space delimited)";
  printf $fmt, "-z",    "Execute a task on hosts from this command's output";
  print "\n";
  printf $fmt, "-K", "Public key file for the ssh connection";
  printf $fmt, "-P", "Private key file for the ssh connection";
  printf $fmt, "-p", "Password for the ssh connection";
  printf $fmt, "-u", "Username for the ssh connection";
  print "\n";
  printf $fmt, "-d",   "Show debug output";
  printf $fmt, "-ddd", "Show more debug output (includes profiling output)";
  printf $fmt, "-m",   "Monochrome output: no colors";
  printf $fmt, "-o",   "Output format";
  printf $fmt, "-q",   "Quiet mode: no log output";
  printf $fmt, "-qw",  "Quiet mode: only output warnings and errors";
  printf $fmt, "-Q",   "Really quiet: output nothing";
  print "\n";
  printf $fmt, "-T",  "List tasks";
  printf $fmt, "-Ta", "List all tasks, including hidden";
  printf $fmt, "-Tm", "List tasks in machine-readable format";
  printf $fmt, "-Tv", "List tasks verbosely";
  printf $fmt, "-Ty", "List tasks in YAML format";
  print "\n";
  printf $fmt, "-c", "Turn cache ON";
  printf $fmt, "-C", "Turn cache OFF";
  printf $fmt, "-f", "Use this file instead of Rexfile";
  printf $fmt, "-F", "Force: disregard lock file";
  printf $fmt, "-h", "Display this help message";
  printf $fmt, "-M", "Load this module instead of Rexfile";
  printf $fmt, "-O", "Pass additional options, like CMDB path";
  printf $fmt, "-s", "Use sudo for every command";
  printf $fmt, "-S", "Password for sudo";
  printf $fmt, "-t", "Number of threads to use (aka 'parallelism' param)";
  printf $fmt, "-v", "Display (R)?ex version";
  print "\n";

  for my $code (@help) {
    &$code();
  }

  CORE::exit 0;

}

sub add_help {
  my ( $self, $code ) = @_;
  push( @help, $code );
}

sub add_exit {
  my ( $self, $code ) = @_;
  push( @exit, $code );
}

sub __version__ {
  print "(R)?ex " . $Rex::VERSION . "\n";
  CORE::exit 0;
}

sub _handle_T {
  my %opts = @_;

  my ($cols) = Term::ReadKey::GetTerminalSize(*STDOUT);
  $Text::Wrap::columns = $cols || 80;

  _list_tasks();
  _list_batches();
  _list_envs();
  _list_groups();
}

sub _list_tasks {
  Rex::Logger::debug("Listing Tasks");

  my @tasks;
  if ( $opts{'a'} ) {
    @tasks = sort Rex::TaskList->create()->get_all_tasks(qr/.*/);
  }
  else {
    @tasks = Rex::TaskList->create()->get_tasks;
  }

  if ( defined $ARGV[0] ) {
    @tasks = grep { $_ =~ /^$ARGV[0]/ } @tasks;

    # Warn if the user passed args to '-T' and no matching task names were found
    Rex::Logger::info( "No tasks matching '$ARGV[0]' found.", "error" )
      unless @tasks;
  }

  return unless @tasks;

  # fancy sorting of tasks -- put tasks from Rexfile first
  my @root_tasks  = grep { !/:/ } @tasks;
  my @other_tasks = grep { /:/ } @tasks;
  @tasks = ( sort(@root_tasks), sort(@other_tasks) );

  _print_color( "Tasks\n", "yellow" );
  my $max_task_len   = max map { length } @tasks;
  my $fmt            = " %-" . $max_task_len . "s  %s\n";
  my $last_namespace = _namespace( $tasks[0] );

  for my $task (@tasks) {
    print "\n" if $last_namespace ne _namespace($task);
    $last_namespace = _namespace($task);

    my $description = Rex::TaskList->create()->get_desc($task);
    my $output      = sprintf $fmt, $task, $description;
    my $indent      = " " x $max_task_len . "   ";

    print wrap( "", $indent, $output );

    if ( $opts{'v'} ) {
      my @servers = sort @{ Rex::TaskList->create()->get_task($task)->server };
      _print_color( "    Servers: " . join( ", ", @servers ) . "\n" );
    }
  }
}

sub _namespace {
  my ($full_task_name) = @_;
  return "" unless $full_task_name =~ /:/;
  my ($namespace) = split /:/, $full_task_name;
  return $namespace;
}

sub _list_batches {
  Rex::Logger::debug("Listing Batches");

  my @batchs = sort Rex::Batch->get_batchs;
  return unless Rex::Batch->get_batchs;

  _print_color( "Batches\n", 'yellow' );
  my $max_batch_len = max map { length } @batchs;
  my $fmt           = " %-" . $max_batch_len . "s  %s\n";

  for my $batch ( sort @batchs ) {
    my $description = Rex::Batch->get_desc($batch);
    my $output      = sprintf $fmt, $batch, $description;
    my $indent      = " " x $max_batch_len . "   ";

    print wrap( "", $indent, $output );

    if ( $opts{'v'} ) {
      my @tasks = Rex::Batch->get_batch($batch);
      _print_color( "    " . join( " ", @tasks ) . "\n" );
    }
  }
}

sub _list_envs {
  Rex::Logger::debug("Listing Envs");

  my @envs =
    map { Rex::Commands->get_environment($_) }
    sort Rex::Commands->get_environments();
  return unless @envs;

  _print_color( "Environments\n", "yellow" ) if scalar @envs;
  my $max_env_len = max map { length $_->{name} } @envs;
  my $fmt         = " %-" . $max_env_len . "s  %s\n";

  for my $e ( sort @envs ) {
    my $output = sprintf $fmt, $e->{name}, $e->{description};
    my $indent = " " x $max_env_len . "   ";
    print wrap( "", $indent, $output );
  }
}

sub _list_groups {
  Rex::Logger::debug("Listing Groups");

  my %groups      = Rex::Group->get_groups;
  my @group_names = sort keys %groups;

  return unless @group_names;

  _print_color( "Server Groups\n", "yellow" );
  my $max_group_len = max map { length } @group_names;
  my $fmt           = " %-" . $max_group_len . "s  %s\n";

  for my $group_name (@group_names) {
    my $hosts  = join( ", ", sort @{ $groups{$group_name} } );
    my $output = sprintf $fmt, $group_name, $hosts;
    my $indent = " " x $max_group_len . "   ";
    print wrap( "", $indent, $output );
  }
}

sub summarize {
  my ($signal) = @_;
  my %opts = Rex::Args->getopts;
  return if $opts{'T'};

  my @summary = Rex::TaskList->create()->get_summary();
  return unless @summary; # no tasks ran -- nothing to summarize

  my @failures = grep { $_->{exit_code} != 0 } @summary;

  if ( !@failures ) {
    Rex::Logger::info("All tasks successful on all hosts");
    return;
  }

  Rex::Logger::info( @failures . " out of " . @summary . " task(s) failed:",
    "error" );

  foreach (
    sort {
           ncmp( $a->{task}, $b->{task} )
        || ncmp( $a->{server}, $b->{server} )
    } @failures
    )
  {
    Rex::Logger::info( "\t$_->{task} failed on $_->{server}", "error" );
    if ( $_->{error_message} ) {
      for my $line ( split( $/, $_->{error_message} ) ) {
        Rex::Logger::info( "\t\t$line", "error" );
      }
    }
  }
}

sub handle_lock_file {
  my $rexfile = shift;

  if ( $^O !~ m/^MSWin/ ) {
    if ( -f "$rexfile.lock" && !exists $opts{'F'} ) {
      Rex::Logger::debug("Found $rexfile.lock");
      my $pid = eval { local ( @ARGV, $/ ) = ("$rexfile.lock"); <>; };
      system(
        "ps aux | awk -F' ' ' { print \$2 } ' | grep $pid >/dev/null 2>&1");
      if ( $? == 0 ) {
        Rex::Logger::info("Rexfile is in use by $pid.");
        CORE::exit 1;
      }
      else {
        Rex::Logger::debug("Found stale lock file. Removing it.");
        Rex::global_sudo(0);
        CORE::unlink("$rexfile.lock");
      }
    }

    Rex::Logger::debug("Creating lock-file ($rexfile.lock)");
    open( my $f, ">", "$rexfile.lock" ) or die($!);
    print $f $$;
    close($f);
  }
  else {
    Rex::Logger::debug("Running on windows. Disabled lock file support.");
  }
}

sub load_server_ini_file {
  my $rexfile = shift;

  # load server ini file
  my $env             = environment;
  my $ini_dir         = dirname($rexfile);
  my $server_ini_file = "$ini_dir/server.$env.ini";
  $server_ini_file = "$ini_dir/server.ini" unless -f $server_ini_file;

  if ( -f $server_ini_file && Rex::Group::Lookup::INI->is_loadable ) {
    Rex::Logger::debug("Loading $server_ini_file");
    Rex::Group::Lookup::INI::groups_file($server_ini_file);
  }
}

sub load_rexfile {
  my $rexfile = shift;
  Rex::Logger::debug("Loading $rexfile");

  if ( !-f $rexfile ) {
    if ( !exists $opts{'e'} ) {
      Rex::Logger::info( "No Rexfile found.", "warn" );
      Rex::Logger::info( "Create a file named 'Rexfile' in this directory,",
        "warn" );
      Rex::Logger::info( "or specify the file you want to use with:", "warn" );
      Rex::Logger::info( "   rex -f file_to_use task_to_run",         "warn" );
    }
    return;
  }

  my $rexfile_dir = dirname $rexfile;
  my @new_inc     = Rex::generate_inc($rexfile_dir);
  @INC = @new_inc;

  # load Rexfile
  eval {

    # add a true return value at the end of $rexfile.
    # we need to do this because perl want a "true" value
    # at the end of a file that is loaded.
    unshift @INC, sub {
      my $load_file = $_[1];
      if ( $load_file eq "__Rexfile__.pm" ) {
        open( my $fh, "<", $rexfile ) or die("Error can't open $rexfile: $!");
        my @content = <$fh>;
        close($fh);
        chomp @content;

        my $i         = 0;
        my $found_end = 0;

        # some rexfile has a __DATA__ or __END__ section
        # and we need to add the true value before those sections.
        for my $line (@content) {
          if ( $line =~ m/^__(DATA|END)__$/ ) {
            splice( @content, $i, 0, "42;" );
            $found_end++;
            last;
          }
          $i++;
        }

        # we didn't found __DATA__ or __END__ so we just add
        # it at the end.
        if ( $found_end == 0 ) {
          push @content, "42;";
        }

        # we can't remove this load from @INC because on perl 5.8
        # this causes a crash
        #shift @INC; # remove this loader from @INC

        # we can't directly return a scalar reference because perl 5.8
        # needs a filehandle. so we create a virtual filehandle...
        my $c = join( "\n", @content );
        open( my $rex_fh, "<", \$c );
        return $rex_fh;
      }
    };

    my ( $stdout, $stderr, $default_stderr );
    open $default_stderr, ">&", STDERR;

    # we close STDERR here because we don't want to see the
    # normal perl error message on the screen. Instead we print
    # the error message in the catch-if below.
    local *STDERR;
    open( STDERR, ">>", \$stderr );

    # we can't use $rexfile here, because if the variable contains dots
    # the perl interpreter try to load the file directly without using @INC
    # so we just fake a module name.
    require __Rexfile__;

    # update %INC so that we can later use it to find the rexfile
    $INC{"__Rexfile__.pm"} = $rexfile;

    # reopen STDERR
    open STDERR, ">&", $default_stderr;

    if ($stderr) {
      my @lines = split( $/, $stderr );
      Rex::Logger::info( "You have some code warnings:", 'warn' );
      Rex::Logger::info( "\t$_",                         'warn' ) for @lines;
    }

    1;
  };

  if ($@) {
    my $e = $@;
    chomp $e;

    # remove the strange path to the Rexfile which exists because
    # we load the Rexfile via our custom code block.
    $e =~ s|/loader/[^/]+/||smg;

    my @lines = split( $/, $e );

    Rex::Logger::info( "Compile time errors:", 'error' );
    Rex::Logger::info( "\t$_",                 'error' ) for @lines;

    exit 1;
  }
}

sub exit_rex {
  my ( $exit_code_override, $signal ) = @_;

  summarize($signal) if !$signal;

  Rex::global_sudo(0);
  Rex::Logger::debug("Removing lockfile") if !exists $opts{'F'};
  unlink("$::rexfile.lock")               if !exists $opts{'F'};

  select STDOUT;

  if ( !$signal && $opts{'o'} && defined( Rex::Output->get ) ) {
    Rex::Output->get->write();
    IPC::Shareable->clean_up_all();
  }

  for my $exit_hook (@exit) {
    $exit_hook->( $exit_code_override, $signal );
  }

  if ($Rex::WITH_EXIT_STATUS) {
    CORE::exit($exit_code_override) if defined $exit_code_override;

    my @exit_codes = Rex::TaskList->create()->get_exit_codes();
    for my $exit_code (@exit_codes) {
      $exit_code = $exit_code >> 8 if $exit_code > 255;
      CORE::exit($exit_code)       if $exit_code != 0;
    }
  }

  CORE::exit(0);
}

# we capture CTRL+C so we can cleanup vars files
# and give modules the chance to also do cleanup
$SIG{INT} = sub {
  exit_rex( 1, "INT" );
};

1;
