package t::Helper;
use strict;
use warnings;

require Exporter;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/test_rex logfile_regex/;

use Test::Builder;
use Test::Cmd;
use Term::ANSIColor qw/colorstrip/;
use Sys::Hostname qw/hostname/;

sub datestrip {
    my @lines = @_;
    $_ =~ s/^\[\d\d\d\d-\d\d-\d\d \d\d\:\d\d\:\d\d\] // for @lines;
    return join "", @lines;
}

sub test_rex {
    my %params = @_;
    $params{stdout} ||= qr/.*/;
    $params{stderr} ||= qr/.*/;

    my $args = $params{args} || die "args param is required";
    my $perl = `which perl`;
    chomp $perl;
    my $prog = "$perl ./bin/rex";
    my $cmd  = "${prog} ${args}";

    my $builder = Test::Builder->new;

    my $subtest = sub {
        my $test = Test::Cmd->new(
            prog    => $prog,
            verbose => $params{verbose} // 0,
            workdir => $params{workdir} // '',
        );

        $test->run(args => $args);

        my $stdout = $test->stdout;
        my $stderr = datestrip colorstrip $test->stderr;

        print "CMD-STDOUT\n$stdout\n" if $params{debug};
        print "CMD-STDERR\n$stderr\n" if $params{debug};

        $builder->level(0); # Shouldn't have to do this?
        $builder->like($stdout, qr|$params{stdout}|m // qr||, 'stdout');
        $builder->like($stderr, qr|$params{stderr}|m // qr||, 'stderr');
        $builder->is_eq($params{exit_code}, $? >> 8, 'exit code');
    };

    $builder->subtest($cmd, $subtest);
}

1;
