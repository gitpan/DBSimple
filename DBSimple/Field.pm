# Copyright (c) 1996-1997 Hugo van der Sanden. All rights reserved. This 
# program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.

package DBSimple::Field;
use strict;
use Carp qw(confess);
use DBSimple::Type;
use vars qw($VERSION);

$VERSION = "0.02";

=head1 NAME

DBSimple::Field - describes fields of tables in databases

=head1 DESCRIPTION

A C<DBSimple::Field> object is used to define the fields of a
C<DBSimple::Table> object in terms of its type (a C<DBSimple::Type>
object), the name of the field as far as the database is concerned,
and the name of the field as far as the script writer is concerned.
(Note that having the two names is intended to free the script
writer from artificial restrictions on field names that may be
imposed by particular database implementations, as well as to permit
the same field name to be used to refer to parallel fields in
different databases even if the tables aren't defined the same.)

All references to fields in the C<DBSimple> suite are mediated
through C<DBSimple::Field> objects. You probably shouldn't need to
use this stuff directly at all.

Everything is a method - nothing is exported.

=head1 CONSTRUCTORS

=over 4

=item scandef ( [ fieldname, localname, type ] ... )

Used by the C<DBSimple::Table> constructor to interpret the list of
field definitions supplied. Returns a reference to an array of
C<DBSimple::Field> objects. The fieldname and localname are taken as
simple strings, and the type definition is passed on to the
C<DBSimple::Type> package for interpretation.

=back

=head1 METHODS

=over 4

=item clone ( )

Returns a blessed deep copy of itself. Used by
C<DBSimple::Table-E<gt>clone>.

=item bind ( database )

I<database> should be a database implementation class derived from
C<DBSimple::DB>. This binds the field, so that it knows how to read
and write itself. Used by C<DBSimple::Table-E<gt>bind>.

=item fieldname ( )

Returns the actual fieldname. Used by database implementation
classes when constructing SQL statements.

=item localname ( )

Returns the local name for the field. Used to discover which field
is being referred to when a local fieldname is supplied.

=item type ( )

Returns the C<DBSimple::Type> object that defines the type of this
field.

=item write ( value )

Returns the text required to insert the given value into this field.
So, for example, strings might need quotes round them and special
characters escaped; numbers might need to be in a particular format.

=item read ( text )

Returns the value represented when the given text comes from this
field.  This might unescape special characters, etc.

=item fielddef ( )

Returns the text required to define this field. Typically used to
build a SQL 'CREATE' statement.

=back

=head1 FUTURE

This bit is all pretty straightforward. Will probably need extra
overrides beyond the existing C<read()>, C<write()> and
C<fielddef()> options.

=head1 HISTORY

v0.02 Hugo 29/3/97

	cleaned up some for external release

v0.01 written by Hugo before 15/11/96

=cut

sub scandef {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my(@defs, $self, $type);
	confess "Invalid field definition list (".@_.")" if @_ % 3;
	while (@_) {
		push @defs, [ shift, shift, shift ];
	}
	[ map {
		bless {
			'fieldname' => shift @$_,
			'localname' => shift @$_,
			'type' => DBSimple::Type->scandef(shift @$_),
		}, $class;
	} @defs ];
}

sub clone {
	my $src = shift;
	my $dest = bless { %$src }, ref $src;
	$dest->{'type'} = $src->type->clone;
	$dest;
}

sub bind {
	shift->type->bind(shift);
}

sub fieldname {
	shift->{'fieldname'};
}

sub localname {
	shift->{'localname'};
}

sub type {
	shift->{'type'};
}

sub write {
	$_[0]->{'type'}->write($_[1]);
}

sub read {
	shift->type->read(@_);
}

sub fielddef {
	shift->type->fielddef(@_);
}

1;
