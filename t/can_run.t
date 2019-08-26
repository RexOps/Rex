use strict;
use warnings;

use Test::More tests => 4;

use Rex::Commands::Run;

{
  my $command_to_check = $^O =~ /^MSWin/ ? 'where' : 'which';
  my $result           = can_run($command_to_check);
  ok( $result, 'Found checker command' );
}

{
  my $command_to_check = "I'm pretty sure this command doesn't exist anywhere";
  my $result           = can_run($command_to_check);
  ok( !$result, 'Non-existing command not found' );
}

{
  my @commands_to_check = $^O =~ /^MSWin/ ? 'where' : 'which';
  push @commands_to_check, 'non-existing command';
  my $result = can_run(@commands_to_check);
  ok( $result, 'Multiple commands - existing first' );
}

{
  my @commands_to_check = $^O =~ /^MSWin/ ? 'where' : 'which';
  unshift @commands_to_check, 'non-existing command';
  my $result = can_run(@commands_to_check);
  ok( $result, 'Multiple commands - non-existing first' );
}
