use Test::More tests => 1;

BEGIN {
  @ARGV = ("-e", "print '';");
  require Rex::CLI;
}

sub Rex::CLI::exit_rex {}

my $cli = Rex::CLI->new;
my $ok = 0;
eval {
  $cli->__run__;
  $ok = 1;
  1;
};

is($ok, 1, "cli eval execution");

