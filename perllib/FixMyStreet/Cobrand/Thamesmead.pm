package FixMyStreet::Cobrand::Thamesmead;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area { return 'Thamesmead'; }
sub council_name { return 'Thamesmead'; }
sub council_url { return 'thamesmead'; }

sub admin_user_domain { ( 'thamesmeadnow.org.uk', 'peabody.org.uk' ) }

sub updates_disallowed {
    my $self = shift;
    my $problem = shift;
    my $c = $self->{c};

    my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->name eq $self->council_name;
    my $superuser = $c->user_exists && $c->user->is_superuser;
    my $reporter = $c->user_exists && $c->user->id == $problem->user->id;
    my $closed_to_updates = $self->SUPER::updates_disallowed($problem);

    if (($staff || $superuser || $reporter) && !$closed_to_updates) {
        return;
    } else {
        return 1;
    }
}

sub reopening_disallowed {
    my $self = shift;
    my $problem = shift;
    my $c = $self->{c};

    my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->name eq $self->council_name;
    my $superuser = $c->user_exists && $c->user->is_superuser;
    my $reporter = $c->user_exists && $c->user->id == $problem->user->id;
    my $reopening_disallowed = $self->SUPER::reopening_disallowed($problem);

    if (($staff || $superuser || $reporter) && !$reopening_disallowed) {
        return;
    } else {
        return 1;
    }
}

sub body {
    my $self = shift;
    my $body = FixMyStreet::DB->resultset('Body')->search({ name => 'Thamesmead' })->first;
    return $body;
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->name eq 'Thamesmead';
}

sub cut_off_date { '2022-04-25' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }

sub default_map_zoom { 6 }

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    %$bodies = map { $_->id => $_ } grep { $_->name eq 'Thamesmead' } values %$bodies;
}

sub privacy_policy_url {
    'https://www.thamesmeadnow.org.uk/terms-and-conditions/privacy-statement/'
}

1;
