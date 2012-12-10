Name:		makethumbs
Summary:	Web gallery generator
Version:	1.239
Release:	4
License:	Public Domain
Group:		Graphics
URL:		http://www.molenda.com/makethumbs/
Source1:	http://www.molenda.com/makethumbs/makethumbs.sh
Source2:	http://www.molenda.com/makethumbs/rotate.sh
Source3:	http://www.molenda.com/makethumbs/doc/makethumbs.sgml
Requires:	imagemagick
Suggests:	metacam jhead
BuildRequires:	docbook-utils-pdf docbook-utils docbook-dtd41-sgml
BuildRequires:	texlive
BuildArch:	noarch
%description
makethumbs.sh and rotate.sh are scripts to create polished, static image
galleries suitable for the web or for a CD-ROM, given a bunch of JPEGs
in a directory. makethumbs is most commonly used in conjunction a digital
camera. Do you want to put a batch of pictures on the web for people to
browse? Once the images are on your system, makethumbs will give you
usable web pages with zero extra work. If you have more than five seconds
to spend on your pictures, makethumbs allows for lots of customization,
labeling, and image descriptions.

%prep

%build
%{__rm} -Rf %{name}-%{version}
mkdir %{name}-%{version}
cd %{name}-%{version}
mkdir html
docbook2html -o html %{SOURCE3}
docbook2pdf %{SOURCE3}

%install
cd %{name}-%{version}
%{__rm} -Rf %{buildroot}
%{__mkdir_p} %{buildroot}%{_bindir}

%{__cp} -p %{SOURCE1} %{buildroot}%{_bindir}/makethumbs.sh
%{__cp} -p %{SOURCE2} %{buildroot}%{_bindir}/rotate.sh

chmod a+x %{buildroot}%{_bindir}/*

%files
%defattr(-,root,root)
%doc %{name}-%{version}/html
%doc %{name}-%{version}/makethumbs.pdf
%{_bindir}/makethumbs.sh
%{_bindir}/rotate.sh


%changelog
* Fri Dec 10 2010 Oden Eriksson <oeriksson@mandriva.com> 1.239-3mdv2011.0
+ Revision: 620293
- the mass rebuild of 2010.0 packages

* Mon Sep 14 2009 Thierry Vignaud <tv@mandriva.org> 1.239-2mdv2010.0
+ Revision: 439702
- rebuild

* Fri Feb 27 2009 Nicolas Vigier <nvigier@mandriva.com> 1.239-1mdv2009.1
+ Revision: 345602
- import makethumbs


