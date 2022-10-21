package FixMyStreet::Cobrand::Birmingham;
use parent 'FixMyStreet::Cobrand::UKCouncils';
sub council_area_id { 2514 }
sub cut_off_date { DateTime->now->subtract(days => 30)->strftime('%Y-%m-%d') }

package main;
use utf8;
use FixMyStreet::Script::UpdateAllReports;

use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { $_[1] });

my $body = $mech->create_body_ok( 2514, 'Birmingham', {}, { cobrand => 'birmingham' } );
$mech->create_body_ok( 2482, 'Bromley', {}, { cobrand => 'bromley' });

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Traffic lights',
    email => 'lights@example.com'
);

my $data;
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard($body);
};

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    TEST_DASHBOARD_DATA => $data,
    ALLOWED_COBRANDS => [ 'fixmystreet', 'birmingham' ],
}, sub {
    ok $mech->host('www.fixmystreet.com');

    subtest 'check marketing dashboard access' => sub {
        # Not logged in, redirected
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';

        $mech->submit_form_ok({ with_fields => { username => 'someone@somewhere.example.org' }});
        $mech->content_contains('did not recognise your email');

        $mech->log_in_ok('someone@somewhere.example.org');
        $mech->get_ok('/reports/Birmingham/summary');
        is $mech->uri->path, '/about/council-dashboard';
        $mech->content_contains('Ending in .gov.uk');

        $mech->submit_form_ok({ with_fields => { name => 'Someone', username => 'someone@birmingham.gov.uk' }});
        $mech->content_contains('Now check your email');

        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        is $mech->uri->path, '/reports/Birmingham/summary';
        $mech->content_contains('Where we send Birmingham');
        $mech->content_contains('lights@example.com');
    };

    subtest 'check marketing dashboard csv' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $mech->create_problems_for_body(105, $body->id, 'Titlē', {
            detail => "this report\nis split across\nseveral lines",
            areas => ",2514,",
        });

        $mech->get_ok('/reports/Birmingham/summary?csv=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 101, '1 (header) + 100 (reports) = 101 lines';

        is scalar @{$rows[0]}, 10, '10 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Title',
                'Category',
                'Created',
                'Confirmed',
                'Status',
                'Latitude',
                'Longitude',
                'Query',
                'Report URL',
            ],
            'Column headers look correct';

        my $body_id = $body->id;
        like $rows[1]->[1], qr/Titlē Test \d+ for $body_id/, 'problem title correct';
    };

    subtest 'check marketing dashboard contact listings' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        $body->send_method('Open311');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports to Birmingham are currently sent directly');

        $body->send_method('Refused');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Birmingham currently does not accept');

        $body->send_method('Noop');
        $body->update();
        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('Reports are currently not being sent');
        $body->send_method('');
        $body->update();

        $mech->log_out_ok();
        $mech->get_ok('/reports');
        $mech->content_lacks('Where we send Birmingham');
    };

    subtest 'check average fix time respects cobrand cut-off date and non-standard reports' => sub {
        $mech->log_in_ok('someone@birmingham.gov.uk');
        my $user = FixMyStreet::DB->resultset('User')->find_or_create({ email => 'counciluser@example.org' });

        # A report created 100 days ago (ie before the cobrand's cut-off), just fixed.
        my ($report1) = $mech->create_problems_for_body(2, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 100),
        });
        $report1->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        # Another report, created 10 days ago, that was just fixed.
        my ($report2) = $mech->create_problems_for_body(2, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 10),
        });
        $report2->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        # Another report, created 10 days ago, that was just fixed.
        my ($report3) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            confirmed => DateTime->now->subtract(days => 1),
            cobrand_data => 'waste',
        });
        $report3->comments->create({
            user      => $user,
            name      => 'A User',
            anonymous => 'f',
            text      => 'fixed the problem',
            state     => 'confirmed',
            mark_fixed => 1,
            confirmed => DateTime->now,
        });

        $mech->get_ok('/about/council-dashboard');
        $mech->content_contains('How responsive is Birmingham?');
        # Average of 55 days means the older problem was included in the calculation.
        $mech->content_lacks('<td>Birmingham</td><td>55 days</td></tr>');
        # 10 days means the older problem was ignored.
        $mech->content_contains('<td>Birmingham</td><td>10 days</td></tr>');
    };
};

subtest 'check heatmap page for cllr' => sub {
    my $user = $mech->create_user_ok( 'cllr@bromley.gov.uk', name => 'Cllr Bromley' );
    my $config = {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { heatmap => { bromley => 1 } },
    };
    FixMyStreet::override_config $config, sub {
        $mech->log_out_ok;
        $mech->get('/dashboard/heatmap');
        is $mech->res->previous->code, 302;
        $mech->log_in_ok($user->email);
        $mech->get('/dashboard/heatmap');
        is $mech->res->code, 404;
    };
    $config->{COBRAND_FEATURES}{heatmap_dashboard_body}{bromley} = 1;
    FixMyStreet::override_config $config, sub {
        $mech->get_ok('/dashboard/heatmap');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'test enforced 2FA for superusers' => sub {
        my $test_email = 'test@example.com';
        my $user = FixMyStreet::DB->resultset('User')->find_or_create({ email => $test_email });
        $user->password('password');
        $user->is_superuser(1);
        $user->update;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('requires two-factor');
    };
};

FixMyStreet::override_config {
    COBRAND_FEATURES => { borough_email_addresses => { fixmystreet => {
        'graffiti@northamptonshire' => [
            { areas => [2397], email => 'graffiti@northampton' },
        ],
    } } },
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Ex-district reports are sent to correct emails' => sub {
        my $body = $mech->create_body_ok( 2397, 'Northampton' );
        my $contact = $mech->create_contact_ok(
            body_id => $body->id,
            category => 'Graffiti',
            email => 'graffiti@northamptonshire',
        );

        my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            latitude => 52.236252,
            longitude => -0.892053,
            cobrand => 'fixmystreet',
            category => 'Graffiti',
        });
        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(1);
        my @email = $mech->get_email;
        is $email[0]->header('To'), 'Northampton <graffiti@northampton>';
    };
};

my $cobrand = FixMyStreet::Cobrand::Birmingham->new;

for my $test (
    {
        update_permission => 'staff',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'none',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'none',
        problem_state => 'closed',
    },
    {
        update_permission => 'staff',
        problem_state => 'closed',
    },
    {
        update_permission => 'reporter-open',
        problem_state => 'closed',
    },
    {
        update_permission => 'open',
        problem_state => 'closed',
    }
) {
    subtest 'Cobrand set to deny updates' => sub {
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
            updates_allowed => { birmingham => $test->{update_permission} },
            },
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test problem', {
             state => "$$test{problem_state}",
        });
        ok($cobrand->deny_updates_by_user($problem), "Reports updates denied with $test->{update_permission} and problem $test->{problem_state}");
        $mech->delete_problems_for_body($body->id);
    };
    };
};

for my $test (
    {
        update_permission => 'reporter',
        problem_state => 'confirmed',
    },
    {
        update_permission => 'reporter',
        problem_state => 'closed',
    },
    {
        update_permission => 'reporter-open',
        problem_state => 'confirmed',
    },
    {
        update_permission => '',
        problem_state => 'confirmed',
    },
    {
        update_permission => '',
        problem_state => 'closed',
    },
    {
        update_permission => 'open',
        problem_state => 'confirmed',
    }
) {
    subtest 'Cobrand set to allow updates' => sub {
        FixMyStreet::override_config {
            COBRAND_FEATURES => {
            updates_allowed => { birmingham => $test->{update_permission} },
            },
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test problem', {
             state => "$$test{problem_state}",
        });
        ok(!$cobrand->deny_updates_by_user($problem), "Reports updates allowed with $test->{update_permission} and problem $test->{problem_state}");
        $mech->delete_problems_for_body($body->id);
    };
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'fixmystreet shows Environment Agency categories' => sub {
        my $bexley = $mech->create_body_ok(2494, 'London Borough of Bexley');
        my $environment_agency = $mech->create_body_ok(2494, 'Environment Agency');
        my $odour_contact = $mech->create_contact_ok(body_id => $environment_agency->id, category => 'Odour', email => 'ics@example.com');
        my $tree_contact = $mech->create_contact_ok(body_id => $bexley->id, category => 'Trees', email => 'foo@bexley');
        $mech->get_ok("/report/new/ajax?latitude=51.466707&longitude=0.181108");
        $mech->content_contains('Trees');
        $mech->content_contains('Odour');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'fixmystreet.com privacy policy page link deactivates correctly' => sub {
        $mech->get_ok('/about/privacy');
        $mech->content_contains('<strong>Privacy and cookies</strong>');
        $mech->content_lacks('<a href="/privacy">Privacy and cookies</a>');
	};
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'fixmystreet changes litter options for National Highways' => sub {
        my $hampshire = $mech->create_body_ok(2227, 'Hampshire County Council');
        my $he = $mech->create_body_ok(2227, 'National Highways');
        $mech->create_contact_ok(body_id => $hampshire->id, category => 'Flytipping', email => 'foo@bexley');
        $mech->create_contact_ok(body_id => $hampshire->id, category => 'Trees', email => 'foo@bexley');
        $mech->create_contact_ok(body_id => $he->id, category => 'Litter (NH)', email => 'litter@he', group => 'National Highways');
        $mech->create_contact_ok(body_id => $he->id, category => 'Potholes (NH)', email => 'potholes@he', group => 'National Highways');

        our $he_mod = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
        sub mock_road {
            my ($name, $litter) = @_;
            $he_mod->mock('_fetch_features', sub {
                my ($self, $cfg, $x, $y) = @_;
                my $road = {
                    properties => { area_name => 'Area 1', ROA_NUMBER => $name, sect_label => "$name/111" },
                    geometry => {
                        type => 'LineString',
                        coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
                    }
                };
                if ($cfg->{typename} eq 'highways_litter_pick') {
                    return $litter ? [$road] : [];
                }
                return [$road];
            });
        }

        # Motorway, NH responsible for litter (but not in dataset), council categories will also be present
        mock_road("M1", 0);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_contains('Litter');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->content_contains('Flytipping');

        # A-road where NH responsible for litter, council categories will also be present
        mock_road("A5103", 1);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_contains('Litter');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->content_contains('Flytipping');

        # A-road where NH not responsible for litter, no NH litter categories
        mock_road("A34", 0);
        $mech->get_ok("/report/new?longitude=-0.912160&latitude=51.015143");
        $mech->content_lacks('Litter');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->content_contains('Flytipping');

        # A-road where NH not responsible for litter, referred to FMS from National Highways
        # ajax call filters NH category to contain only litter related council subcategories
        mock_road("A34", 0);
        my $j = $mech->get_ok_json("/report/new/ajax?w=1&longitude=-0.912160&latitude=51.015143&he_referral=1");
        my $tree = HTML::TreeBuilder->new_from_content($j->{subcategories});
        my @elements = $tree->find('input');
        is @elements, 1, 'Only one subcategory in National Highways category';
        is $elements[0]->attr('value') eq 'Flytipping', 1, 'Subcategory is Flytipping';
    };
};

done_testing();
