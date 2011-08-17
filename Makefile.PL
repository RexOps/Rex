use ExtUtils::MakeMaker;

my %deps = (
                  'Net::SSH2' => '>0.33',
                  'DBI' => 0,
                  'XML::Simple' => 0,
                  'LWP::UserAgent' => 0,
                  'MIME::Base64' => 0,
                  'Digest::HMAC_SHA1' => 0,
                  'HTTP::Date' => 0,
                  'JSON::XS' => 0,
);

if($^O =~ m/^MSWin/) {
}
else {
   $deps{"Expect"} = 0;
}

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => \%deps,
   EXE_FILES => ['bin/rex', 'bin/rexify'],
   LICENSE => 'GPL'
);

