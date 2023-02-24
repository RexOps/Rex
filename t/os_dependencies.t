use 5.12.5;
use warnings;

use Test::More;
use Rex::Commands;

my $dependency_ref = case $^O, {
  qr{MSWin} => [qw(Net::SSH2 Win32::Console::ANSI)],
    default => [qw(Net::OpenSSH Net::SFTP::Foreign IO::Pty)],
};

my @dependencies = @{$dependency_ref};

plan tests => scalar @dependencies;

for my $module (@dependencies) {
  ok( eval "use $module; 1;", "$module is available" );
}
