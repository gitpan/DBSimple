# Copyright (c) 1996-1997 Hugo van der Sanden. All rights reserved. This 
# program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.

package DBSimple::Table;
use strict;
use Carp qw(confess);
use DBSimple::Field;
use vars qw($VERSION);

$VERSION = "0.03";

=head1 NAME

DBSimple::Table - the interface to tables in the C<DBSimple> abstraction

=head1 SYNOPSIS

	use DBSimple::Table;
	my $table = new DBSimple::Table('my_table', [ qw(
		NAME        user_name       char:20NK
		BALANCE     account_balance real:N
		LASTPAID    last_payment    real
		ACCTYPE     account_type    char:2
	)]);
	my $indexfield = $table->field('user_name');
	my $db = &dbdef;	# get an open DBSimple::DB object
	$table->bind($db);
	sub dbfind {
		map { bless { %$_ } } $table->select($indexfield, \@_);
	}
	.. etc

=head1 DESCRIPTION

The intention here is to provide a simple, portable access mechanism to
database tables, such that the script writer does not need to know what
type of database the table is stored in, nor on what machine it is
hosted. B<THE MECHANISMS DESCRIBED HERE ARE LIKELY TO CHANGE> so don't
get too wedded to them unless you are happy to keep any necessary
maintenance and extension to yourself.

You acquire a C<DBSimple::Table> object by supplying the table name and
definitions for the fields - see C<DBSimple::Field-E<gt>scandef> for a
definition of the field declaration format.

If you have a collection of identical tables, supply the undefined value
as the table name, then for each table C<clone> the C<DBSimple::Table>
object supplying the tablename at this point. C<bind> a database only
to the named clone.

You won't be able to do anything with your C<DBSimple::Table> object until
you C<bind> a database to it - this should be an object returned by
C<DBSimple::DB-E<gt>new>. Even then, you'll still need to C<open> the
database before you can access the table.

That done, you can do (or if you can't, you'll be able to eventually)
everything you want to on the database. You can refer to fields
throughout either by the C<DBSimple::Field> object or by its local name;
all values you supply or get returned will be the actual value (string,
number etc) cleansed of any munging required to fit it in the database;
NULL values are translated to undef.

I've tried to make the return types useful, but they may not always be
as expected.

See the B<FUTURE> section below for some indication of how things will
change.

=head1 CONSTRUCTOR

=over 4

=item new ( tablename, fieldarrayref )

Creates and returns a new C<DBSimple::Table> object. If the I<tablename>
is undefined, this is purely a table format specification: see C<clone>
for a way of using this for multiple identical tables. The I<fieldarrayref>
is a reference to a list with three elements per field: the fieldname,
the localname, and the type - see C<DBSimple::Field-E<gt>scandef()> for
a fuller description. You need to C<bind> the C<DBSimple::Table> object
before you can use it.

=back

=head1 METHODS

=head2 Doing things with the object

=over 4

=item clone ( [ tablename ] )

Creates and returns a deep copy of the object. If a I<tablename> is
supplied, and the table name of the original object is undefined, the
clone will acquire this as its name. To be honest, using this to get
a named copy of an unnamed table format specification is about the
only use for this method I can think of.

=item bind ( database )

I<database> should be a database implementation class derived from
C<DBSimple::DB>.  This tells the table how to do everything it needs to
do. You'll still need to C<open> the I<database> before you can
actually do it though.

=item unbind

Theoretically, this unbinds a previously bound database so that you
can re-bind a different one. I've never used it, so don't be surprised
if it doesn't work. I suspect it isn't terribly useful though.

=item name

Returns the name of the table.

=item fields

Returns a reference to an array of the C<DBSimple::Field> objects defined
for this table.

=item field ( localname )

Returns the C<DBSimple::Field> object for the requested I<localname>.

=item fieldindex ( localname | fieldobject )

Returns the index in the C<fields> list for the requested field.

=back

=head2 Doing things with the whole table

=over 4

=item exists ( )

True if the table exists, else false.

=item recreate ( dataref )

Rebuilds an entire table: the table is dropped if it exists, then
recreated to have all the fields it is defined with, then the I<dataref>
data is inserted into it. I<dataref> is of the same format required for
the C<insert> method.

=item drop ( )

Drops the table. The table must exist.

=item create ( )

Creates the table with the fields it is defined to have. If order is
important, the order of fields will be the same as the order they were
specified for the table definition.

=back

=head2 Doing things with rows of the table

=over 4

=item insert ( [ fieldarrayref, ] dataref )

Inserts new rows into the database. I<dataref> is a reference to an
array of rows; each row is a reference either to an array of field
values or to a hash of localnames (which may be blessed into some
package).  If the I<fieldarrayref> is provided, it should be a list of
field localnames or C<DBSimple::Field> objects, else the full list of
fields for the table is assumed. Each row in the I<dataref> should
supply one value for each field to be inserted, with undefined values
being inserted as NULL values.

=item delete ( where ... )

Deletes rows from the table that match a condition. See C<where>
below for details of how to specify a condition.

=item update ( field, value, where ... )

Updates a field in the table to a new value, in each row that matches
a condition. The I<field> specified may be a localname or a C<DBSimple::Field>
object. The value must be a constant - you can't use this to set a value
that depends on the row found. See C<where> below for details of how to
specify a condition.

=item select ( where ... )

Selects all fields from those rows that match a condition. Returns an
array of results, each result a reference to a hash in which the keys are
the local names of the C<DBSimple::Field>s. If called in a scalar context,
a reference to the array is returned. See C<where> below for details of
how to specify a condition.

=item selectf ( fieldarrayref, where ... )

Selects the requested fields from those rows that match a condition.
Return values are as for C<select>. You can specify the fields either
by their localname, or by the full C<DBSimple::Field> object.

=item selectmax ( field, where ... )

Selects all fields from the row for which the requested I<field> has the
greatest value (either numerically or in ASCII order), of those rows that
also match the condition. The I<field> can be specified either as a
localname or as a C<DBSimple::Field> object. Return values are as for
C<select> - you get back an array of one result, or a reference to that
array.

=item like ( field, match )

Selects all fields from rows where the requested I<field> matches the
I<match> string. The I<field> is expected to be a text field, and can
be specified either as a localname or as a C<DBSimple::Field> object.
This does standard SQL LIKE-matching, with return values as for C<select>.

=item likef ( fieldarrayref, field, match )

Selects the requested fields from rows where the requested I<field>
matches the I<match> string. Each field can be specified either as a
localname or as a C<DBSimple::Field> object. Return values are as for
C<like>.

=item clike ( field, match )

Selects all fields from rows where the requested I<field> matches the
I<match> string in a case-insensitive match. The I<field> is expected
to be a text field, and can be specified either as a localname or as a
C<DBSimple::Field> object. Depending on the database implementation,
this functionality may be missing, or implemented as a full select
followed by post-processing to pick the matches.
Return values are as for C<select>.

=item clikef ( fieldarrayref, field, match )

As C<clike> when you want to specify which fields are returned.

=back

=head1 Specifying conditions ('where' clauses)

The conditions arguments currently severely restrict the range of
queries you can do, which is one reason why there all those
different methods above rather than a single C<select()> method.
Each pair consists of a field specifier and a match specifier.
The field specifier can in all cases be either a C<DBSimple::Field>
object or a localname; the match specifier can be either a
scalar (string, number or undef as appropriate) or a reference to
an array of values.

If the match specifier is an arrayref, the field is permitted to
match any of the supplied values; if a scalar, the field must contain
exactly that value. Each field/value pair must be satisfied
simultaneously. Thus a 'where' set of

	( 'name' => 'hugo', 'email' => [ 'hv', 'root' ] )

could result in SQL like any of these:

	.. where NAME = 'hugo' and EMAIL in ('hv', 'root')
	.. where NAME = 'hugo' and (EMAIL = 'hv' or EMAIL = 'root')
	.. where EMAIL = 'hv' or EMAIL = 'root' and NAME = 'hugo'

Note that the latter will work correctly only if the SQL parser
works left to right (as Msql's does).

At the point this mechanism is redesigned (as it must be), it may
be possible to support the current behaviour (since the new
behaviour will probably take a single C<DBSimple::Where> object or
somesuch, whereas the current one always takes an even number of
arguments), but don't count on it.

=head1 FUTURE

Coo, lots. Redesign the data access mechanism - there shouldn't be
separate routines for each different type of selection, instead there
should be some sort of C<Where> object you can build up piecemeal, that
can give access to the full power of the SQL-engine you are using. That
ain't gonna be easy - just thinking about joins and nested selects is
likely to make my head hurt.

The fieldname lookup is a broken concept too - you can speed things up
some by using C<field> to get the field objects, but the code here still
has to check each one in case it needs upgrading from a localname. Of
course, that also means it needs to know where the field specifiers are
in the arguments, even inside data structures, which limits the
flexibility of the routines (though the C<@cond[_half @cond]> is a
middling cool hack). Which is, of course, why we have the silly separate
routines in the first place.

It's a major hassle having to copy all the arguments before doing the
lookup, but beware that it's necessary: if an argument was supplied as
a literal, trying to upgrade it I<in situ> in C<@_> will die with an
'attempt to modify read-only value' error. (Yes, I tried. Twice.)

A hash of fieldnames to lookup C<DBSimple::Field> objects would be some
improvement, even though there shouldn't be enough fields in a table to
make it that relevant.

I could go on ...

=head1 HISTORY

v0.03 Hugo 29/3/97

	cleaned up some for external release
	documented C<where>

v0.02 Hugo 25/2/97

	remove 'dropif' method; add 'exists' method
	amended documentation of 'insert' method

v0.01 written by Hugo before 15/11/96

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = bless {
		'name' => shift,
		'bound' => 0,
	}, $class;
	$self->{'fields'} = DBSimple::Field->scandef(@{+shift});
	$self;
}

sub clone {
	my $src = shift;
	my $dest = bless { %$src }, ref $src;
	$dest->{fields} = [ map $_->clone, @{$src->fields} ];
	$dest->{name} = shift if @_;
	$dest;
}

sub bind {
	my $self = shift;
	return if defined $self->{db};
	my $db = shift;
	$self->{db} = $db;
	grep $_->bind($db) && 0, @{$self->fields};
	$self->{bound} = 1;
}

sub unbind {
	my $self = shift;
	delete $self->{db};
	$self->{bound} = 0;
}

sub _half ($) {
	map $_ << 1, 0 .. (shift) / 2 - 1;
#or grep !($_ & 1), 0 .. (shift) - 1;
}

sub recreate {
	my $self = shift;
	$self->drop if $self->exists;
	$self->create;
	$self->insert(shift);
}

sub exists {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	$self->{db}->exists($self->name);
}

sub drop {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	$self->{db}->drop($self->name);
}

sub create {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	$self->{db}->create($self->name, $self->fields);
}

sub insert {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my $fields;
	if (@_ > 1) {
		$fields = shift;
		foreach (@$fields) {
			$_ = $self->field($_) unless ref $_;
		}
	} else {
		$fields = $self->fields;
	}
	$self->{db}->insert($self->name, $fields, shift);
}

sub delete {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my @cond = @_;
	foreach (@cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->delete($self->name, @cond);
}

sub update {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my($field, $value) = (shift, shift);
	my @cond = @_;
	foreach ($field, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->update($self->name, $field, $value, @cond);
}

# select all fields
sub select {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my @cond = @_;
	foreach (@cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->select($self->name, $self->fields, @cond);
}

sub selectf {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my $fields = shift;
	my @cond = @_;
	foreach (@$fields, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->select($self->name, $fields, @cond);
}

sub selectmax {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my $maxfield = shift;
	my @cond = @_;
	foreach ($maxfield, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->selectmax($self->name, $self->fields, $maxfield, @cond);
}

sub like {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my($field, $match, @cond) = @_;
	foreach ($field, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->like($self->name, $self->fields, $field, $match, @cond);
}

sub likef {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my $fields = shift;
	my($field, $match, @cond) = @_;
	foreach (@$fields, $field, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->like($self->name, $fields, $field, $match, @cond);
}

sub clike {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my($field, $match, @cond) = @_;
	foreach ($field, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->clike($self->name, $self->fields, $field, $match, @cond);
}

sub clikef {
	my $self = shift;
	confess "'$self' not bound to a database" unless $self->{bound};
	my $fields = shift;
	my($field, $match, @cond) = @_;
	foreach (@$fields, $field, @cond[_half @cond]) {
		$_ = $self->field($_) unless ref $_;
	}
	$self->{db}->clike($self->name, $fields, $field, $match, @cond);
}

sub name {
	shift->{'name'};
}

sub fields {
	shift->{'fields'};
}

sub fieldindex {
	my $self = shift;
	my $fields = $self->fields;
	confess "Usage: \$table->fieldindex('fieldname')" unless @_ == 1;
#	map {
#		my $field = $_;
		my $field = shift;
		$field = $field->localname if ref $field;
#		scalar((grep $field eq $fields->[$_]->localname, 0 .. $#$fields)[0])
		my @x = grep $field eq $fields->[$_]->localname, 0 .. $#$fields;
		$x[0];
#	} @_;
}

sub field {
	my $self = shift;
	my $localname = shift;
#	scalar((grep $_->localname eq $localname, @{$self->fields})[0]);
	my @x = grep $_->localname eq $localname, @{$self->fields};
	confess "No such field '$localname' in $self" unless @x;
	shift @x;
}

1;
