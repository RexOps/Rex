%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex

Summary: Rex is a tool to ease the execution of commands on multiple remote servers.
Name: rex
Version: 0.6.0
Release: 1
License: Artistic
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-0.6.0.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl-Net-SSH2
BuildRequires: perl >= 5.8.0
BuildRequires: perl(ExtUtils::MakeMaker)
Requires: perl-Net-SSH2
Requires: perl-Expect
Requires: perl-DBI
Requires: perl >= 5.8.0
Requires: rsync

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
* Sat Jun 11 2011 Jan Gehring <jan.gehring at, gmail.com> 0.6.0-1
- extended download function to work with urls (http, ftp)
- fixed bug in syntax check
- add console parameters to needs calls as default
- do_task now accepts an arrayRef to call multiple tasks at once
- check if package is installed, before the installation
- added tail function
- added cat function
- added -q cli parameter. for no debugging output at all.
- added rex-master and rex-agent

* Sat Jun 04 2011 Jan Gehring <jan.gehring at, gmail.com> 0.5.1-1
- fixed chdir command
- fixed typo in documentation
- documentation updates

* Thu Mar 31 2011 Jan Gehring <jan.gehring at, gmail.com> 0.3.1-1
- initial rpm


