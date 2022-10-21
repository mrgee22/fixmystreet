package Integrations::Bartec;

use strict;
use warnings;
use DateTime;
use DateTime::Format::W3CDTF;
use Memcached;
use Moo;
use FixMyStreet;

with 'FixMyStreet::Roles::SOAPIntegration';
with 'FixMyStreet::Roles::ParallelAPI';

has attr => ( is => 'ro', default => 'http://bartec-systems.com/' );
has action => ( is => 'lazy', default => sub { $_[0]->attr . "/Service/" } );
has username => ( is => 'ro' );
has password => ( is => 'ro' );
has url => ( is => 'ro' );
has auth_url => ( is => 'ro' );

has sample_data => ( is => 'ro', default => 0 );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs' unless $ENV{DEV_USE_SYSTEM_CA_PATH};
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $self->action . $_[1]; } )->proxy($self->url);
        return $soap;
    },
);

has auth_endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs' unless $ENV{DEV_USE_SYSTEM_CA_PATH};
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $self->action . $_[1]; } )->proxy($self->auth_url);
        return $soap;
    },
);

has token => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $key = "peterborough:bartec_token";
        my $token = Memcached::get($key);
        unless ($token) {
            my $result = $self->Authenticate;
            $token = $result->{Token}->{TokenString};
            Memcached::set($key, $token, 60*30);
        }
        return $token;
    },
);

has backend_type => ( is => 'ro', default => 'bartec' );

sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    @params = make_soap_structure_with_attr(@params);
    my $som = $self->endpoint->call(
        SOAP::Data->name($method)->attr({ xmlns => $self->attr }),
        @params
    );
    my $res = $som->result;
    $res->{SOM} = $som;
    return $res;
}

sub Authenticate {
    my ($self) = @_;

    require SOAP::Lite;
    my @params = make_soap_structure_with_attr(user => $self->username, password => $self->password);
    my $res = $self->auth_endpoint->call(
        SOAP::Data->name("Authenticate")->attr({ xmlns => $self->attr }),
        @params
    );
    $res = $res->result;
    return $res;
}

# Given a postcode, returns an arrayref of addresses
sub Premises_Get {
    my $self = shift;
    my $pc = shift;

    if ($self->sample_data) {
        return [
          {
            'RecordStamp' => {
                               'AddedBy' => 'dbo',
                               'DateAdded' => '2018-11-12T14:22:23.3'
                             },
            'Ward' => {
                        'RecordStamp' => {
                                           'DateAdded' => '2018-11-12T13:53:01.53',
                                           'AddedBy' => 'dbo'
                                         },
                        'Name' => 'North',
                        'ID' => '3620',
                        'WardCode' => 'E05010817'
                      },
            'USRN' => '30101339',
            'UPRN' => '100090215480',
            'Location' => {
                            'BNG' => '',
                            'Metric' => {
                                          'Latitude' => '52.599211',
                                          'Longitude' => '-0.255387'
                                        }
                          },
            'Address' => {
                           'Town' => 'PETERBOROUGH',
                           'PostCode' => 'PE1 3NA',
                           'Street' => 'POPE WAY',
                           'Address1' => '',
                           'Address2' => '1',
                           'Locality' => 'NEW ENGLAND'
                         },
            'UserLabel' => ''
          },
          {
            'UserLabel' => '',
            'Address' => {
                           'Address1' => '',
                           'Locality' => 'NEW ENGLAND',
                           'Address2' => '10',
                           'Street' => 'POPE WAY',
                           'PostCode' => 'PE1 3NA',
                           'Town' => 'PETERBOROUGH'
                         },
            'Location' => {
                            'Metric' => {
                                          'Latitude' => '52.598583',
                                          'Longitude' => '-0.255515'
                                        },
                            'BNG' => ''
                          },
            'UPRN' => '100090215489',
            'USRN' => '30101339',
            'Ward' => {
                        'WardCode' => 'E05010817',
                        'RecordStamp' => {
                                           'AddedBy' => 'dbo',
                                           'DateAdded' => '2018-11-12T13:53:01.53'
                                         },
                        'Name' => 'North',
                        'ID' => '3620'
                      },
            'RecordStamp' => {
                               'AddedBy' => 'dbo',
                               'DateAdded' => '2018-11-12T14:22:23.3'
                             }
          },
        ];
    }

    my $res = $self->call('Premises_Get', token => $self->token, Postcode => $pc);
    my $som = $res->{SOM};

    my @premises;

    my $i = 1;
    for my $premise ( $som->valueof('//Premises') ) {
        # extract the lat/long from attributes on the <Metric> element
        $premise->{Location}->{Metric} = $som->dataof("//Premises_GetResult/[$i]/Location/Metric")->attr;
        push @premises, $premise;
        $i++;
    }

    return \@premises;
}

sub Premises_FutureWorkpacks_Get {
    my ( $self, %args ) = @_;

    my $res = $self->call(
        'Premises_FutureWorkpacks_Get',
        token    => $self->token,
        UPRN     => $args{uprn},
        DateFrom => $args{date_from},
        DateTo   => $args{date_to},
    );

    # Already seem to be returned from Bartec in date ascending order, but
    # we'll sort just in case
    my $workpacks = force_arrayref( $res, 'Premises_FutureWorkPack' );
    @$workpacks
        = sort { $a->{WorkPackDate} cmp $b->{WorkPackDate} } @$workpacks;
    return $workpacks;
}

sub WorkPacks_Get {
    my ( $self, %args ) = @_;

    my $res = $self->call(
        'WorkPacks_Get',
        token => $self->token,
        Date  => {
            MinimumDate => {
                attr  => { xmlns => "http://www.bartec-systems.com" },
                value => $args{date_from},
            },
            MaximumDate => {
                attr  => { xmlns => "http://www.bartec-systems.com" },
                value => $args{date_to},
            },
        },
    );

    return force_arrayref( $res, 'WorkPack' );
}

sub Jobs_Get {
    my ($self, $uprn) = @_;

    my $w3c = DateTime::Format::W3CDTF->new;

    # how many days before today to search for jobs
    # The assumption is that collections have a minimum frequency of every two weeks, so a day of wiggle room.
    my $days_buffer = 15;

    my $start = $w3c->format_datetime(DateTime->now->subtract(days => $days_buffer));
    my $end = $w3c->format_datetime(DateTime->now);

    my $res = $self->call('Jobs_Get', token => $self->token, UPRN => $uprn, ScheduleStart => {
        MinimumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $start,
        },
        MaximumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $end,
        },
    });
    my $jobs = force_arrayref($res, 'Jobs');
    @$jobs = sort { $a->{ScheduledStart} cmp $b->{ScheduledStart} } map { $_->{Job} } @$jobs;
    return $jobs;
}

# TODO Merge with Jobs_Get() above
sub Jobs_Get_for_workpack {
    my ( $self, $workpack_id ) = @_;

    my $res = $self->call(
        'Jobs_Get',
        token      => $self->token,
        WorkPackID => $workpack_id,
    );

    return force_arrayref( $res, 'Jobs' );
}

sub Jobs_FeatureScheduleDates_Get {
    my ($self, $uprn, $start, $end) = @_;

    my $w3c = DateTime::Format::W3CDTF->new;

    # how many days before today to search for collections if $start/$end aren't given.
    # The assumption is that collections have a minimum frequency of every two weeks, so a day of wiggle room.
    my $days_buffer = 15;

    $start = $w3c->format_datetime($start || DateTime->now->subtract(days => $days_buffer));
    $end = $w3c->format_datetime($end || DateTime->now->add(days => $days_buffer));

    my $res = $self->call('Jobs_FeatureScheduleDates_Get', token => $self->token, UPRN => $uprn, DateRange => {
        MinimumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $start,
        },
        MaximumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $end,
        },
    });
    my $data = force_arrayref($res, 'Jobs_FeatureScheduleDates');

    # The data may contain multiple schedules for the same JobName because one
    # is ending and another starting, so one will lack a NextDate (represented
    # as a 1900 timestamp), the other a PreviousDate; or an old ended schedule
    # may still be present. Loop through and work out the closest previous and
    # next dates to use.
    my (%min_next, %max_last);
    my $out;
    foreach (@$data) {
        my $name = $_->{JobName};
        my $last = $_->{PreviousDate};
        my $next = $_->{NextDate};
        $last = undef if $last lt '2000';
        $next = undef if $next lt '2000';
        $min_next{$name} = $next if $next && (!defined($min_next{$name}) || $min_next{$name} gt $next);
        $max_last{$name} = $last if $last && (!defined($max_last{$name}) || $max_last{$name} lt $last);
        $out->{$name} = {
            %$_,
            PreviousDate => $max_last{$name},
            NextDate => $min_next{$name},
        };
    }

    return [ values %$out ];
}

sub Features_Schedules_Get {
    my $self = shift;
    my $uprn = shift;

    # This SOAP call fails if the <Types> element is missing, so the [undef] forces an empty <Types /> element
    return force_arrayref($self->call('Features_Schedules_Get', token => $self->token, UPRN => $uprn, Types => [undef]), 'FeatureSchedule');
}

sub ServiceRequests_Get {
    my ($self, $uprn) = @_;

    my $requests = $self->call('ServiceRequests_Get', token => $self->token, UPRNs => { decimal => $uprn });
    return force_arrayref($requests, 'ServiceRequest');
}

sub Premises_Attributes_Get {
    my ($self, $uprn) = @_;

    my $attributes = $self->call('Premises_Attributes_Get', token => $self->token, UPRN => $uprn );
    return force_arrayref($attributes, 'Attribute');
}

sub Premises_Events_Get {
    my ($self, $uprn) = @_;

    my $from = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->subtract(months => 1);
    my $events = $self->call('Premises_Events_Get',
        token => $self->token, UPRN => $uprn, DateRange => ixhash(MinimumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $from->iso8601,
        }, MaximumDate => {
            attr => { xmlns => "http://www.bartec-systems.com" },
            value => $from->clone->add(months=>3)->iso8601
        }));
    return force_arrayref($events, 'Event');
}

sub Streets_Events_Get {
    my ($self, $usrn) = @_;

    my $from = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->subtract(months => 1);
    my $events = $self->call('Streets_Events_Get',
        token => $self->token, USRN => $usrn, StartDate => $from->iso8601 );
    return force_arrayref($events, 'Event');
}

sub Features_Types_Get {
    my ($self) = @_;
    # This expensive operation doesn't take any params so may as well cache it
    my $key = "peterborough:bartec:Features_Types_Get";
    my $types = Memcached::get($key);
    unless ($types) {
        $types = force_arrayref($self->call('Features_Types_Get', token => $self->token), 'FeatureType');
        Memcached::set($key, $types, 60*30);
    }
    return $types;
}

1;
