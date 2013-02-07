%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex

Summary: Rex is a tool to ease the execution of commands on multiple remote servers.
Name: rex
Version: 0.39.0
Release: 1
License: Apache 2.0
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-0.39.0.tar.gz
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

* Thu Feb 07 2013 Jan Gehring <jan.gehring at, gmail.com> 0.39.0-1
- updated release

* Sun Jan 27 2013 Jan Gehring <jan.gehring at, gmail.com> 0.38.0-1
- updated release

* Wed Jan 16 2013 Jan Gehring <jan.gehring at, gmail.com> 0.37.2-1
- updated release

* Tue Jan 15 2013 Jan Gehring <jan.gehring at, gmail.com> 0.37.1-1
- updated release

* Sat Jan 05 2013 Jan Gehring <jan.gehring at, gmail.com> 0.37.0-1
- updated release

* Tue Jan 01 2013 Jan Gehring <jan.gehring at, gmail.com> 0.36.0-1
- updated release

* Sat Dec 22 2012 Jan Gehring <jan.gehring at, gmail.com> 0.35.1-1
- updated release

* Fri Dec 14 2012 Jan Gehring <jan.gehring at, gmail.com> 0.34.2-1
- updated release

* Sun Nov 25 2012 Jan Gehring <jan.gehring at, gmail.com> 0.34.1-1
- updated release

* Thu Nov 02 2012 Jan Gehring <jan.gehring at, gmail.com> 0.34.0-1
- updated release
