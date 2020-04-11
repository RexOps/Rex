#
# (c) Nathan Abu <aloha2004@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::XML - read hostnames and groups from a XML file

=head1 DESCRIPTION

With this module you can define hostgroups out of an xml file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::XML;
 groups_xml "file.xml";


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Group::Lookup::XML;

use strict;
use warnings;
use Rex -base;

# VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
XML::LibXML->require;

@EXPORT = qw(groups_xml);

=head2 groups_xml($file)

With this function you can read groups from xml files.

File example:

 <configuration>
   <group name="database">
       <server name="machine01" user="root" password="foob4r" sudo="true" hdd="300" loc="/opt" />
   </group>
   <group name="application">
       <server name="machine01" user="root" password="foob4r" sudo="true" hdd="50" loc="/export" />
       <server name="machine02" user="root" password="foob5r" sudo="true"/>
   </group>
   <group name="profiler">
       <server name="machine03" user="root" password="blue123"/>
   </group>
 </configuration>
 
The XML file is validated against the DTD schema stored in C<Rex::Group::Lookup::XML::$schema_file> as string.
 
=cut

=head2 $schema_file

A variable that contains the XSD schema for which the XML is validated against.

=cut

our $schema_file = <<"XSD";
<xsd:schema attributeFormDefault="unqualified" elementFormDefault="qualified" version="1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema">

    <xsd:element name="configuration">
        <xsd:complexType>
            <xsd:sequence>

                <xsd:element minOccurs="1" maxOccurs="unbounded" name="group">
                    <xsd:complexType>
                        <xsd:sequence>

                            <xsd:element name="server" minOccurs="1" maxOccurs="unbounded">
                                <xsd:complexType>
                                    <xsd:attribute name="name" use="required" type="xsd:string" />
                                    <xsd:anyAttribute processContents="lax"/>
                                </xsd:complexType>
                            </xsd:element>

                        </xsd:sequence>
                        <xsd:attribute use="required" name="name" type="xsd:string" />
                    </xsd:complexType>
                </xsd:element>

            </xsd:sequence>
        </xsd:complexType>
    </xsd:element>

</xsd:schema>
XSD

sub xml_validate {
  my $xmldoc = shift;
  my $schema = XML::LibXML::Schema->new( string => $schema_file );

  eval { $schema->validate($xmldoc); 1 }
    or die "Could not validate XML file against the XSD schema: $@";
}

sub groups_xml {
  my $file   = shift;
  my $parser = XML::LibXML->new();
  my $xmldoc = $parser->parse_file($file);
  my %groups;

  xml_validate($xmldoc);

  foreach my $server_node ( $xmldoc->findnodes('/configuration/group/server') )
  {
    my ($group) =
      map { $_->getValue() }
      grep { $_->nodeName eq 'name' } $server_node->parentNode->attributes();
    my %atts =
      map { $_->nodeName => $_->getValue() } $server_node->attributes();

    push(
      @{ $groups{$group} },
      Rex::Group::Entry::Server->new( name => delete( $atts{name} ), %atts )
    );
  }
  group( $_ => @{ $groups{$_} } ) foreach ( keys(%groups) );
}

1;
