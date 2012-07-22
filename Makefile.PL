use ExtUtils::MakeMaker;

my %deps = (
                  'Net::SSH2' => '0.33',
                  'DBI' => 0,
                  'XML::Simple' => 0,
                  'LWP::UserAgent' => 0,
                  'MIME::Base64' => 0,
                  'Digest::HMAC_SHA1' => 0,
                  'HTTP::Date' => 0,
                  'JSON::XS' => 0,
                  'YAML' => 0,
                  'LWP::Simple' => 0,
                  'DB_File' => 0,
);

if($^O =~ m/^MSWin/) {
}
else {
   $deps{"Expect"} = 0;
}

WriteMakefile1(
   META_MERGE => {
      resources => {
         repository => 'https://github.com/krimdomu/Rex',
      },
   },
   #BUILD_REQUIRES => {
   #},

   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => \%deps,
   EXE_FILES => ['bin/rex', 'bin/rexify'],
   LICENSE => 'Apache License 2.0'
);


sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
   my %params=@_;
   my $eumm_version=$ExtUtils::MakeMaker::VERSION;
   $eumm_version=eval $eumm_version;
   die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
   die "License not specified" if not exists $params{LICENSE};
   if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
      #EUMM 6.5502 has problems with BUILD_REQUIRES
      $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
      delete $params{BUILD_REQUIRES};
   }
   delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
   delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
   delete $params{META_MERGE} if $eumm_version < 6.46;
   delete $params{META_ADD} if $eumm_version < 6.46;
   delete $params{LICENSE} if $eumm_version < 6.31;
   delete $params{AUTHOR} if $] < 5.005;
   delete $params{ABSTRACT_FROM} if $] < 5.005;
   delete $params{BINARY_LOCATION} if $] < 5.005;

   WriteMakefile(%params);
}

