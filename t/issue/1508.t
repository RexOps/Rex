
=head1 NAME 

issue/1508.t  - Check that the `needs()` function correctly propogates run-time task arguments

=head1 DESCRIPTION

Check that the `needs()` function does indeed correctly propogate 
run-time task arguments (%params and @args) from the calling task down to the "needed" tasks.

=head1 DETAILS

  * AUTHOR / DATE : [tabulon]@[2021-09-26]
  * RELATES-TO    : [github issue #1508](https://github.com/RexOps/Rex/issues/1508#issue-1007457392)
  * INSPIRED from : t/needs.t

=cut

use Test::More;
use Rex::Commands;

{

  package T; # Helper package (for cutting down boilerplate in tests)
  use Storable;

  sub track_taskrun {
    my %opts = ref $_[-1] eq 'HASH'
      ? %{
      ;
      pop
      }
      : ();
    my $argv    = $opts{argv};
    my @prereqs = (@_);
    for (@prereqs) {
      my $file = "${_}.txt";
      Storable::store( $argv, $file );
    }
  }

  sub check_needed {
    my %opts = ref $_[-1] eq 'HASH'
      ? %{
      ;
      pop
      }
      : ();
    my $argv      = $opts{argv};
    my $do_unlink = delete $opts{unlink} // 1;
    my @prereqs   = (@_);

    for (@prereqs) {
      my $file = "${_}.txt";

      -f "$file" or die;
      my $propagated_argv = Storable::retrieve("$file");
      Test::More::_deep_check( $propagated_argv, $argv ) or die;

      unlink("$file") if ($do_unlink);
    }
  }
}

{

  package MyTest;
  use strict;
  use warnings;
  use Rex::Commands;

  $::QUIET = 1;

  task test1 => sub {
    T::track_taskrun( test1 => { argv => \@_ } );
  };

  task test2 => sub {
    T::track_taskrun( test2 => { argv => \@_ } );
  };

  1;
}

{

  package Nested::Module;

  use strict;
  use warnings;

  use Rex::Commands;

  task test => sub {
    T::track_taskrun( test => { argv => \@_ } );
  };
}

{

  package Rex::Module;

  use strict;
  use warnings;

  use Rex::Commands;

  task test => sub {
    T::track_taskrun( test => { argv => \@_ } );
  };
}

task test => sub {
  needs MyTest;

  T::check_needed( $_, { argv => \@_ } ) for (qw/test1 test2/);
};

task test2 => sub {
  needs MyTest "test2";

  T::check_needed( $_, { argv => \@_ } ) for (qw/test2/);
};

task test3 => sub {
  needs "test4";

  T::check_needed( $_, { argv => \@_ } ) for (qw/test4/);
};

task test4 => sub {
  T::track_taskrun( test4 => { argv => \@_ } );
};

task test5 => sub {
  needs Nested::Module test;

  T::check_needed( $_, { argv => \@_ } ) for (qw/test/);
};

task test6 => sub {
  needs Rex::Module "test";

  T::check_needed( $_, { argv => \@_ } ) for (qw/test /);
};



{
  my $task_list = Rex::TaskList->create;
  my $run_list  = Rex::RunList->instance;
  $run_list->parse_opts(qw/test test2 test3 test5 test6/);

  for my $task ( $run_list->tasks ) {
    my $name = $task->name;
    my %prms = ( "${name}_greet" => "Hello ${name}" );
    my @args = ( "${name}.arg.0", "${name}.arg.1", "${name}.arg.2" );

    $task_list->run($task);

    my @summary = $task_list->get_summary;
    is_deeply $summary[-1]->{exit_code}, 0, $task->name;
    $run_list->increment_current_index;
  }
}

done_testing;
