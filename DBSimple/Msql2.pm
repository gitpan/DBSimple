# Copyright (c) 1996-1997 Hugo van der Sanden. All rights reserved. This 
# program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.

package DBSimple::Msql2;
use strict;
use Carp qw(confess);
use Msql;
use DBSimple::Type;
use vars qw($VERSION);

$VERSION = "0.02";
&init;

=head1 NAME

DBSimple::Msql2 - C<DBSimple> implementation class for Msql v2 databases

=head1 DESCRIPTION

You shouldn't need to use this: all this stuff should be called
transparently by C<DBSimple::DB> or C<DBSimple::Table> objects.

If the environment variable B<SQL_DEBUG> is defined, each SQL statement
will be warned to STDERR.

=head1 FUTURE

Try to keep up with future changes to C<DBSimple::Table>.

=head1 HISTORY

v0.02 Hugo 29/3/97

	cleaned up some for external release

v0.01 written by Hugo 6/3/97

	This is a thinly disguised copy of the DBSimple::Msql code

=cut

sub init {
	my $factory = bless {};
	my %types = (
		'char' => {
			'dobefore' => sub {
				my $self = shift;
				confess "'$self': must declare size"
					unless defined $self->{size};
			},
			'write' => sub {
				return 'NULL' unless defined $_[1];
				warn "String longer than field" if length $_[1] > $_[0]->{size};
				Msql->quote($_[1]);
			},
		},
		'int' => {
			'write' => sub { defined $_[1] ? ($_[1] || 0) : 'NULL' },
		},
		'real' => {
			'write' => sub { defined $_[1] ? ($_[1] || 0) : 'NULL' },
		},
	);
	map DBSimple::Type->register($factory, $_, $types{$_}), keys %types;
}

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	bless {
		'host' => shift,
		'name' => shift,
	}, $class;
}

sub open {
	my $self = shift;
	$self->{dbh} ||= Msql->connect($self->{host}, $self->{name});
	$self;
}

sub sqlvoid {
	my $self = shift;
	warn "SQL: $_[0]\n" if defined $::ENV{'SQL_DEBUG'};
	$self->{dbh}->query(shift);
}

sub sqlmap {
	my $self = shift;
	my $fields = shift;
	warn "SQL: $_[0]\n" if defined $::ENV{'SQL_DEBUG'};
	my $query = $self->{dbh}->query(shift);
	my $row;
	my $results = [ map {
		$row = [ $query->fetchrow ];
		+{ map {
			( $fields->[$_]->localname => $fields->[$_]->read($row->[$_]) )
		} 0 .. $#$row }
	} 1 .. $query->numrows ];
	wantarray ? @$results : $results;
}

sub sqlmaprange {
	my $self = shift;
	my $fields = shift;
	my $range = shift;
	warn "SQL: $_[0]\n" if defined $::ENV{'SQL_DEBUG'};
	my $query = $self->{dbh}->query(shift);
	my $row;
	my $results = [ map {
		if (@$range) {
			if ($range->[0] == $_) {
				shift @$range;
				$row = [ $query->fetchrow ];
				+{ map { (
					$fields->[$_]->localname => $fields->[$_]->read($row->[$_])
				) } 0 .. $#$row }
			} else {
				$query->fetchrow;
				+()
			}
		} else {
			+()
		}
	} 0 .. $query->numrows - 1 ];
	wantarray ? @$results : $results;
}

sub exists {
	my $self = shift;
	my $table = shift;
	!!grep $_ eq $table, $self->{dbh}->listtables;
}

sub drop {
	my $self = shift;
	my $table = shift;
	$self->sqlvoid("drop table $table");
}

sub create {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	$self->sqlvoid(<<SQL);
create table $table (@{[
	join ", ", map $_->fieldname . " " . $_->fielddef, @$fields
]})
SQL
}

sub update {
	my $self = shift;
	my $table = shift;
	my $update = _sqlequal(shift, shift);
	$self->sqlvoid("update $table set $update @{[ $self->allwhere(@_) ]}");
}

sub insert {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	my $data = shift;
	my $object;
	my $fieldstr = join ", ", map $_->fieldname, @$fields;
	my $i;
	for ($i = $#$data; $i >= 0; --$i) {
		$object = $data->[$i];
		$self->sqlvoid(<<SQL);
insert into $table ($fieldstr)
values (@{[
	join ", ", (ref($object) eq 'ARRAY')
		? map($fields->[$_]->write($object->[$_]), 0 .. $#$fields)
		: map $_->write($object->{$_->localname}), @$fields ]})
SQL
	}
}

sub selectmax {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	my $maxfield = shift;
	($self->sqlmaprange($fields, [ 0 ], <<SQL))[0];
select @{[ join ", ", map $_->fieldname, @$fields ]}
	from $table @{[ $self->allwhere(@_) ]}
	order by @{[ $maxfield->fieldname ]} desc
SQL
}

sub delete {
	my $self = shift;
	my $table = shift;
	$self->sqlvoid("delete from $table @{[ $self->allwhere(@_) ]}");
}

sub select {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	$self->sqlmap($fields, <<SQL);
select @{[ join ", ", map $_->fieldname, @$fields ]}
	from $table @{[ $self->allwhere(@_) ]}
SQL
}

sub like {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	my $field = shift->fieldname;
	my $match = Msql->quote(shift);
	$self->sqlmap($fields, <<SQL);
select @{[ join ", ", map $_->fieldname, @$fields ]}
	from $table @{[ $self->somewhere(@_) ]} $field like $match
SQL
}

sub clike {
	my $self = shift;
	my $table = shift;
	my $fields = shift;
	my $field = shift->fieldname;
	my $match = Msql->quote(shift);
	$self->sqlmap($fields, <<SQL);
select @{[ join ", ", map $_->fieldname, @$fields ]}
	from $table @{[ $self->somewhere(@_) ]} $field clike $match
SQL
}

sub allwhere {
	my $text = shift->where(@_);
	length $text ? "where $text" : "";
}

sub somewhere {
	my $text = shift->where(@_);
	length $text ? "where $text and " : "where ";
}

# Msql limitations:
# - maximum 75 fields per query
# - clause scanned left to right, no brackets allowed
sub where {
	my $self = shift;
	confess "Mismatched select conditions" if @_ & 1;
	my(@singles, $multiple, $field, $match);
	while (@_) {
		($field, $match) = (shift, shift);
		if (ref($match) eq 'ARRAY') {
			confess "Too many multiples in select conditions"
				if defined $multiple;
			$multiple = [ $field, $match ];
		} else {
			push @singles, [ $field, $match ];
		}
	}
	if (defined $multiple) {
		($field, $match) = @$multiple;
		confess "Too many fields in select condition"
			if @singles + @$match > 74;
		join(" or ", map _sqlequal($field, $_), @$match)
				. map " and " . _sqlequal(@$_), @singles;
	} elsif (@singles) {
		confess "Too many fields in select condition"
			if @singles > 74;
		join " and ", map _sqlequal(@$_), @singles;
	} else {
		"";
	}
}

sub _sqlequal {
	my $field = shift;
	$field->fieldname . " = " . $field->write(shift);
}

sub type {
	'Msql2';
}

1;
