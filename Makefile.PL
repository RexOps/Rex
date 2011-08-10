use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => {
                  'Net::SSH2' => '>0.33',
                  'Expect' => 0,
                  'DBI' => 0,
                  'XML::Simple' => 0,
                  'LWP::UserAgent' => 0,
                  'MIME::Base64' => 0,
                  'Digest::HMAC_SHA1' => 0,
                  'HTTP::Date' => 0,
                  'JSON::XS' => 0,
                  },
   EXE_FILES => ['bin/rex', 'bin/rexify'],
   LICENSE => 'GPL3'
);

