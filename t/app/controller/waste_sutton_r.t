use utf8;
use JSON::MaybeXS;
use Path::Tiny;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $body = $mech->create_body_ok(2498, 'Sutton Council', $params, { cobrand => 'sutton' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staff = $mech->create_user_ok('staff@example.net', name => 'Staff User', from_body => $body->id);
$staff->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' }, 'Waste',
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
);
create_contact({ category => 'Request new container', email => '1635' }, 'Waste',
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 1, automated => 'hidden_field' },
    { code => 'Reason', required => 1, automated => 'hidden_field' },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'sutton',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { sutton => {
            url => 'http://example.org/',
        } },
        waste => { sutton => 1 },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
}, sub {
    my ($e) = shared_echo_mocks();
    subtest 'Address lookup' => sub {
        set_fixed_time('2022-09-10T12:00:00Z');
        $mech->get_ok('/waste/12345');
        $mech->content_contains('2 Example Street, Sutton');
        $mech->content_contains('Every Friday fortnightly');
        $mech->content_contains('Friday, 2nd September');
        $mech->content_contains('Report a mixed recycling collection as missed');
    };
    subtest 'Request a new bin' => sub {
        $mech->get_ok('/waste/12345/request');
		# 19 (1), 24 (1), 16 (1), 1 (1)
        # missing, new_build, more
        $mech->submit_form_ok({ with_fields => { 'container-19' => 1 }});
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Sutton, SM1 1AA\n\nReason: Damaged";
        is $report->category, 'Request new container';
        is $report->title, 'Request new Green paper and cardboard bin';
    };
    subtest 'Report a new recycling raises a bin delivery request' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/waste/12345/request');
        $mech->submit_form_ok({ with_fields => { 'container-16' => 1 } });
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'more' }});
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Quantity: 1\n\n2 Example Street, Sutton, SM1 1AA";
        is $report->title, 'Request new Green recycling box';
    };
    subtest 'Request bins from front page' => sub {
        $mech->get_ok('/waste/12345');
        $mech->submit_form_ok({ with_fields => { 'container-1' => 1 } });
        $mech->content_contains('name="container-1" value="1"');
        $mech->content_contains('Green paper and cardboard bin');
        $mech->content_contains('Green recycling box');
        $mech->content_contains('Food waste bin (outdoor)');
        $mech->content_contains('Brown rubbish bin');
    };
    subtest 'Report missed collection' => sub {
        $mech->get_ok('/waste/12345/report');
		$mech->content_contains('Food waste');
		$mech->content_contains('Mixed recycling');
		$mech->content_contains('Non-recyclable Refuse');
		$mech->content_lacks('Paper and card');

        $mech->submit_form_ok({ with_fields => { 'service-2239' => 1 } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('collection has been reported');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->detail, "Report missed Food waste\n\n2 Example Street, Sutton, SM1 1AA";
        is $report->title, 'Report missed Food waste';
    };
    subtest 'No reporting/requesting if open request' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            # Request
            EventTypeId => 1635,
            Data => { ExtensibleDatum => [
                { Value => 2, DatatypeName => 'Source' },
                {
                    ChildData => { ExtensibleDatum => [
                        { Value => 1, DatatypeName => 'Action' },
                        { Value => 16, DatatypeName => 'Container Type' },
                    ] },
                },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling container request has been made');
        $mech->content_contains('Report a mixed recycling collection as missed');
        $mech->get_ok('/waste/12345/request');
        $mech->content_like(qr/name="container-16"[^>]*disabled/s); # green

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 1566,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 408,
            Data => { ExtensibleDatum => [
                { Value => 1, DatatypeName => 'Container Mix' },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A mixed recycling collection has been reported as missed');
        $mech->content_contains('Request a mixed recycling container');

        $e->mock('GetEventsForObject', sub { [ {
            EventTypeId => 1566,
            EventDate => { DateTime => "2022-09-10T17:00:00Z" },
            ServiceId => 408,
            Data => { ExtensibleDatum => [
                { Value => 1, DatatypeName => 'Paper' },
            ] },
        } ] });
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A paper and card collection has been reported as missed');

        $e->mock('GetEventsForObject', sub { [] }); # reset
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
}, sub {
    subtest 'Sutton staff can see Kingston admin' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/admin/');
    };
};

sub shared_echo_mocks {
    my $e = Test::MockModule->new('Integrations::Echo');
    $e->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.359723, Longitude => -0.193146 } },
            Description => '2 Example Street, Sutton, SM1 1AA',
        };
    });
    $e->mock('GetServiceUnitsForObject', sub {
        return decode_json(path(__FILE__)->sibling('waste_4443082.json')->slurp_utf8);
    });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    return $e;
}

done_testing;
