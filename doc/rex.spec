%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex

Summary: Rex is a tool to ease the execution of commands on multiple remote servers.
Name: rex
Version: 0.32.1
Release: 1
License: Apache 2.0
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-0.32.1.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl-Net-SSH2
BuildRequires: perl >= 5.8.0
BuildRequires: perl(ExtUtils::MakeMaker)
Requires: libssh2 >= 1.2.8
Requires: perl-Net-SSH2
Requires: perl-Expect
Requires: perl-DBI
Requires: perl >= 5.8.0
Requires: rsync
Requires: perl-libwww-perl
Requires: perl-XML-Simple
Requires: perl-Digest-HMAC
Requires: perl-YAML

%description
Rex is a tool to ease the execution of commands on multiple remote 
servers. You can define small tasks, chain tasks to batches, link 
them with servers or server groups, and execute them easily in 
your terminal.

%prep
%setup -n %{real_name}-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install

### Clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;


%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root, 0755)
%doc META.yml 
%doc %{_mandir}/*
%{_bindir}/*
%{perl_vendorlib}/*

%changelog

* Thu Aug 30 2012 Jan Gehring <jan.gehring at, gmail.com> 0.32.1-1
- updated release

* Sat Aug 18 2012 Jan Gehring <jan.gehring at, gmail.com> 0.32.0-1
- updated release

* Thu Aug 16 2012 Jan Gehring <jan.gehring at, gmail.com> 0.31.5-1
- updated release

* Sat Aug 04 2012 Jan Gehring <jan.gehring at, gmail.com> 0.31.4-1
- updated release
