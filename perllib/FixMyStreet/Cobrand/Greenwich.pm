package FixMyStreet::Cobrand::Greenwich;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2493; }
sub council_area { return 'Royal Borough of Greenwich'; }
sub council_name { return 'Royal Borough of Greenwich'; }
sub council_url { return 'greenwich'; }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Royal Greenwich postcode, or street name and area';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Greenwich';

    # as it's the requested example location, try to avoid a disambiguation page
    $town .= ', SE10 0EF' if $string =~ /^\s*woolwich\s+r(?:oa)?d\s*(?:,\s*green\w+\s*)?$/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.4743770385684,0.0555696523982184',
        span   => '0.089851200483885,0.150572372434415',
        bounds => [ 51.423679096602, -0.0263872255863898, 51.5135302970859, 0.124185146848025 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub reports_per_page { return 20; }

sub admin_user_domain { 'royalgreenwich.gov.uk' }

sub send_questionnaires { 0 }

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    # Greenwich doesn't have category metadata to fill this
    my $open311_only = [
        { name => 'external_id', value => $row->id },
    ];

    if ($row->geocode) {
        my $address = $row->geocode->{resourceSets}->[0]->{resources}->[0]->{address};
        push @$open311_only, (
            { name => 'closest_address', value => $address->{formattedAddress} }
        );
        $h->{closest_address} = '';
    }

    return $open311_only;
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1, closest_address => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
    }
}

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $contact = $update->problem->contact || return 0;
    my $endpoint = $contact->endpoint || return 0;
    return 1 if $endpoint eq 'https://open311.royalgreenwich.gov.uk/';
    return 0;
}

1;
