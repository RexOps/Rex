use strict;
use warnings;

use Test::More;
use Test::UseAllModules;

BEGIN {
  all_uses_ok except => qw(
    Rex::Commands::DB
    Rex::Commands::Rsync
    Rex::Group::Lookup::DBI
    Rex::Helper::DBI
    Rex::Interface::Connection::OpenSSH
    Rex::Interface::Connection::SSH
    Rex::Interface::Exec::OpenSSH
    Rex::Interface::Exec::SSH
    Rex::Interface::File::OpenSSH
    Rex::Interface::File::SSH
    Rex::Interface::Fs::OpenSSH
    Rex::Interface::Fs::SSH
    Rex::Output
    Rex::Output::JUnit
  );
}
