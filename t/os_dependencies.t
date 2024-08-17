#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;
use Rex::Commands;

my $dependency_ref = case $^O, {
  qr{MSWin} => [qw(Net::SSH2 Win32::Console::ANSI)],
    default => [qw(Net::OpenSSH Net::SFTP::Foreign IO::Pty)],
};

my @dependencies = @{$dependency_ref};

plan tests => @dependencies + 1;

for my $module (@dependencies) {
  ok( eval "use $module; 1;", "$module is available" );
}
