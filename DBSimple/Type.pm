# Copyright (c) 1996-1997 Hugo van der Sanden. All rights reserved. This 
# program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.

package DBSimple::Type;
use strict;
use Carp qw(confess);
use vars qw($VERSION);

$VERSION = "0.03";
my %registry;

=head1 NAME

DBSimple::Type - describes types of fields in tables in databases

=head1 DESCRIPTION

An C<DBSimple::Type> object is used to define the type of each
C<DBSimple::Field> object. Each database implementation must
register which types it knows how to handle, along with any special
instructions for the handling of those types. When you call
C<DBSimple::Table-E<gt>bind>, the binding propagates down to the
C<DBSimple::Type> for each field, at which point the special
instructions for each particular field type are attached.

All references to types in the C<DBSimple> suite are mediated
through C<DBSimple::Type> objects. You probably shouldn't need to
use this stuff directly at all.
 
Everything is a method except for C<DBSimple::Type-E<gt>register>;
nothing is exported.

=head1 CONSTRUCTORS

=over 4

=item new ( type, [ attributes hash | attributes hashref ] )

Creates and returns a new C<DBSimple::Type> object. Additional
attributes may be specified, and are mostly ignored except by means
of the special instructions a database implementation may register.
Default handling, however, recognises 3 attributes called 'size',
'notnull' and 'key', where 'size' is the maximum permitted length of
a char (string) field, 'notnull' is 1 if the field is not permitted
to be undefined (else 0), and 'key' is 1 if the field is the primary
key for the table (else 0).

=item scandef ( def )

Parses a type definition and returns a new C<DBSimple::Type> object
that describes it. The definition consists of the type name
(typically 'char', 'int' or 'real') on its own, or followed by a ':'
and additional attributes information, consisting of any or all of a
sequence of digits representing the maximum size of the field, an
'N' if the field is not permitted to be set to NULL, or a 'K' if the
field is the primary key for the table. If more than one attribute
is specified, they must appear in the order described above.

=back

=head1 METHODS

=over 4

=item clone ( )

Returns a blessed deep copy of itself. Used by
C<DBSimple::Field-E<gt>clone>.

=item bind ( database )

I<database> should be a database implementation class derived from
C<DBSimple::DB>.  This binds the type, so that it knows how to read
and write itself. Used by C<DBSimple::Field-E<gt>bind>.

=item read ( text )

Returns the value represented when the given text comes from a field
of this type. Uses the 'read' method registered for this type in
this database, if defined, else returns the text unaltered.

=item write ( value )

Returns the text required to insert the given value into a field of
this type. Uses the 'write' method registered for this type in this
database, if defined, else returns the value unaltered.

=item fielddef ( )

Returns the text required to define a field of this type. Uses the
'fielddef' method registered for this type in this database, if
defined, else attempts to build a default string. This string is
typically used to build a SQL 'CREATE' statement, and the default
will cope with simple cases using no more than the attributes it
knows about.

=back

=head1 FUNCTIONS

=over 4

=item register ( database, type, [ bindings hash | bindings hashref ] )

Registers the bindings for a particular type relevant to a
particular database implementation. Each of the bindings ties a code
reference to a particular name, which is assumed to be one of the
overrides available: 'read', 'write' or 'fielddef'.

Each such code reference, when called, will be passed a type object
as the first parameter, followed by any other parameters relevant to
the call.

=back

=head1 FUTURE

Dunno how useful this abstraction will turn out to be once we have a
need for some other database implementations, but I'm fairly hopeful.

=head1 HISTORY

v0.03 Hugo 29/3/97

	cleaned up some for external release

v0.02 Hugo 3/3/97

	Unroll calls to _doself for efficiency

v0.01 written by Hugo before 15/11/96

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $type = shift;
	@_ = %{ +shift } if @_ && ref $_[0] eq 'HASH';
	my $self = bless {
		'type' => $type,
		'bound' => 0,
		@_
	}, $class;
	$self->bind($self->{db}) if defined $self->{db};
	$self;
}

sub scandef {
	my $self = shift;
	my $string = shift;
	if ($string =~ /^(.*):(\d*)(N?)(K?)$/) {
		my %args;
		$args{'size'} = $2 if length $2;
		$args{'notnull'} = 1 if length $3;
		$args{'key'} = 1 if length $4;
		$self->new($1, %args);
	} else {
		$self->new($string);
	}
}

sub clone {
	my $src = shift;
	my $dest = bless { %$src }, ref $src;
	$dest;
}

sub bind {
	my $self = shift;
	$self->{db} = shift if @_;
	confess "'$self': no database defined" unless defined $self->{db};
	confess "'$self' already bound" if $self->{bound};
	my $dbtype = $self->{db}->type;
	confess "'$self': '$self->{db}' has unknown type '$dbtype'"
		unless defined $registry{$dbtype};
	my $reg = $registry{$dbtype}{$self->{'type'}};
	confess "'$self': type '$self->{'type'}' not defined for '$dbtype' databases"
		unless defined $reg;
	&{$reg->{dobefore}}($self) if defined $reg->{dobefore};
	@{$self}{keys %$reg} = values %$reg;
	&{$reg->{doafter}}($self) if defined $reg->{doafter};
	delete $self->{dobefore};
	delete $self->{doafter};
	$self->{bound} = 1;
	$self;
}

sub _doself {
	my $self = shift;
	my $func = $self->{+shift};
	defined $func ? &$func($self, @_) : @_;
}

sub write {
#	shift->_doself('write', @_);
	defined $_[0]->{'write'} ? &{$_[0]->{'write'}}(@_) : $_[1];
}

sub read {
#	shift->_doself('read', @_);
	my $self = shift;
	my $func = $self->{'read'};
	defined $func ? &$func($self, @_) : @_;
}
 
sub fielddef {
	my $self = shift;
	my $func = $self->{'fielddef'};
	return  &$func($self) if defined $func;
	my $def = $self->{type};
	$def .= "($self->{size})" if defined $self->{size};
	$def .= " not null" if $self->{notnull};
	$def .= " primary key" if $self->{key};
	$def;
}

sub register {
	my $proto = shift;
	my $db = shift;
	my $type = shift;
	my $dbtype = ref $db ? $db->type : $db;
	confess "'$db' doesn't know its name" unless defined $dbtype;
	confess "'$type' already defined for '$dbtype'"
		if defined $registry{$dbtype}{$type};
	@_ = %{ +shift } if @_ && ref $_[0] eq 'HASH';
	$registry{$dbtype}{$type} = { @_ };
}

1;
