package Net::DNS::RR::MX;
#
# $Id: MX.pm 319 2005-05-30 17:12:09Z olaf $
#
use strict;
use bytes;
use vars qw(@ISA $VERSION);

@ISA     = qw(Net::DNS::RR);
$VERSION = (qw$LastChangedRevision: 319 $)[1];

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		($self->{"preference"}) = unpack("\@$offset n", $$data);
		
		$offset += Net::DNS::INT16SZ();
		
		($self->{"exchange"}) = Net::DNS::Packet::dn_expand($data, $offset);
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && ($string =~ /^(\d+)\s+(\S+)$/)) {
		$self->{"preference"} = $1;
		$self->{"exchange"}   = $2;
		$self->{"exchange"}   =~ s/\.+$//;;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return defined $self->{"preference"}
	       ? "$self->{preference} $self->{exchange}."
	       : '';
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"preference"}) {
		$rdata .= pack("n", $self->{"preference"});
		$rdata .= $packet->dn_comp($self->{"exchange"},
					   $offset + length $rdata);
	}

	return $rdata;
}

sub _canonicalRdata {
    my ($self) = @_;
    my $rdata = "";
    
    if (exists $self->{"preference"}) {
	$rdata .= pack("n", $self->{"preference"});
	$rdata .= $self->_name2wire($self->{"exchange"})
	}
    
    return $rdata;
}


1;
__END__

=head1 NAME

Net::DNS::RR::MX - DNS MX resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Mail Exchanger (MX) resource records.

=head1 METHODS

=head2 preference

    print "preference = ", $rr->preference, "\n";

Returns the preference for this mail exchange.

=head2 exchange

    print "exchange = ", $rr->exchange, "\n";

Returns name of this mail exchange.

=head1 COPYRIGHT

Copyright (c) 1997-2002 Michael Fuhr. 

Portions Copyright (c) 2002-2004 Chris Reinhardt.

All rights reserved.  This program is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 3.3.9

=cut
