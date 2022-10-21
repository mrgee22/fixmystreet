use DateTime::Format::Strptime;
use FixMyStreet::Cobrand::Peterborough;
use Test::Fatal;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::More;

# TODO Mocked time not being picked up on, why?

# Friday, 31 December 2021 23:59:59 GMT
# set_fixed_time(1640995199);

# subtest '_bulky_collection_window' => sub {
#     is_deeply(
#         FixMyStreet::Cobrand::Peterborough->_bulky_collection_window(),
#         {   date_from => '2021-12-31',
#             date_to   => '2022-03-29',
#         },
#     );
# };

subtest 'find_available_bulky_slots' => sub {
    my $dummy_property = { uprn => 123456789 };
    my $mock_bartec    = Test::MockModule->new('Integrations::Bartec');
    $mock_bartec->mock(
        'WorkPacks_Get',
        sub {
            my ( undef, %args ) = @_;
            my $wp = _workpacks_by_date()->{ $args{date_from} };
            return $wp ? $wp : _workpacks_by_date()->{ $args{date_to} };
        },
    );
    $mock_bartec->mock(
        'Jobs_Get_for_workpack',
        sub {
            my ( undef, $workpack_id ) = @_;
            return _jobs_by_workpack_id()->{$workpack_id};
        },
    );

    my $cobrand = FixMyStreet::Cobrand::Peterborough->new;
    $cobrand->{c} = Test::MockObject->new;
    my %session_hash;
    $cobrand->{c}->mock( session => sub { \%session_hash } );

    $mock_bartec->mock( 'Premises_FutureWorkpacks_Get', &_future_workpacks );
    is_deeply(
        $cobrand->find_available_bulky_slots($dummy_property),
        [   {   date        => '2022-08-05T00:00:00',
                workpack_id => 75474,
            },
            {   date        => '2022-09-02T00:00:00',
                workpack_id => 75496,
            },
            {   date        => '2022-09-09T00:00:00',
                workpack_id => 75497,
            },
            {   date        => '2022-09-16T00:00:00',
                workpack_id => 75498,
            },
        ],
    );

    my $start_date = '2022-09-17';
    $mock_bartec->mock( 'Premises_FutureWorkpacks_Get',
        &_future_workpacks($start_date) );
    is_deeply(
        $cobrand->find_available_bulky_slots( $dummy_property, $start_date ),
        [   {   date        => '2022-09-23T00:00:00',
                workpack_id => 75499,
            },
            {   date        => '2022-09-30T00:00:00',
                workpack_id => 75500,
            },
            {   date        => '2022-10-07T00:00:00',
                workpack_id => 75600,
            },
            {   date        => '2022-10-08T00:00:00',
                workpack_id => 75800,
            },
            {   date        => '2022-10-09T00:00:00',
                workpack_id => 75900,
            },
        ],
    );

    is_deeply(
        [ sort keys %session_hash ],
        [   'peterborough:bartec:available_bulky_slots:earlier:123456789',
            'peterborough:bartec:available_bulky_slots:later:123456789',
        ],
        'cache keys should be set',
    );

    %session_hash = ();
    like(
        exception {
            $cobrand->find_available_bulky_slots( $dummy_property,
                '17-09-22' )
        },
        qr/Invalid date provided/,
    );
};

# For Premises_FutureWorkpacks_Get() calls
sub _future_workpacks {
    my $start_date = shift;
    my $fw         = [
        # No black bin - ignored
        {   'id'           => 57127,
            'WorkPackDate' => '2022-07-29T00:00:00',
            'WorkPackName' => 'Waste-Round 2 Garden-290722',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Brown' } },
        },

        {   'id'           => 75474,
            'WorkPackDate' => '2022-08-05T00:00:00',
            'WorkPackName' => 'Waste-Round 16-050822',
            'Actions'      => {
                'Action' => [
                    { 'ActionName' => 'Empty 1100l Refuse' },
                    { 'ActionName' => 'Empty Bin 240L Black' }
                ],
            },
        },

        {   'id'           => 75481,
            'WorkPackDate' => '2022-08-12T00:00:00',
            'WorkPackName' => 'Waste-Round 16-120822',
            'Actions'      => [
                { 'ActionName' => 'Empty 1100l Refuse' },
                { 'ActionName' => 'Empty Bin 240L Black' }
            ],
        },

        {   'id'           => 75488,
            'WorkPackDate' => '2022-08-19T00:00:00',
            'WorkPackName' => 'Waste-Round 16-190822',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75495,
            'WorkPackDate' => '2022-08-26T23:59:59',
            'WorkPackName' => 'Waste-Round 16-260822',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75496,
            'WorkPackDate' => '2022-09-02T00:00:00',
            'WorkPackName' => 'Waste-Round 16-020922',
            'Actions'      => { 'ActionName' => 'Empty Bin 240L Black' },
        },

        {   'id'           => 75497,
            'WorkPackDate' => '2022-09-09T00:00:00',
            'WorkPackName' => 'Waste-Round 16-090922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75498,
            'WorkPackDate' => '2022-09-16T00:00:00',
            'WorkPackName' => 'Waste-Round 16-160922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75499,
            'WorkPackDate' => '2022-09-23T00:00:00',
            'WorkPackName' => 'Waste-Round 16-230922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75500,
            'WorkPackDate' => '2022-09-30T00:00:00',
            'WorkPackName' => 'Waste-Round 16-300922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        # In reality this shouldn't happen, but test for two black bin WPs
        # for the same day
        {   'id'           => 75600,
            'WorkPackDate' => '2022-10-07T00:00:00',
            'WorkPackName' => 'Waste-Round 16-071022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'id'           => 75700,
            'WorkPackDate' => '2022-10-07T00:00:00',
            'WorkPackName' => 'Waste-Round 17-071022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        # Extra workpacks, to test that the number of available slot dates is
        # not limited if a start date is provided to
        # find_available_bulky_slots()
        {   'id'           => 75800,
            'WorkPackDate' => '2022-10-08T00:00:00',
            'WorkPackName' => 'Waste-Round 16-081022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'id'           => 75900,
            'WorkPackDate' => '2022-10-09T00:00:00',
            'WorkPackName' => 'Waste-Round 16-091022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
    ];

    if ($start_date) {
        return [
            grep {
                my $parser
                    = DateTime::Format::Strptime->new( pattern => '%F' );
                $parser->parse_datetime( $_->{WorkPackDate} )
                    >= $parser->parse_datetime($start_date);
            } @$fw
        ];
    } else {
        return $fw;
    }
}

# For WorkPacks_Get() calls
sub _workpacks_by_date {
    {
        # No bulky workpacks; i.e. no booked bulky collections
        '2022-08-05T00:00:00' => [
            {   'ID'          => '508221',
                'Name'        => 'Waste-R5 Ref-050822',
                'RecordStamp' => {},                      # Not relevant
            },
        ],

        # Workpacks with jobs that exceed the bulky limit:

        # 'WHITES' (bulky) workpack
        '2022-08-12T00:00:00' => [
            {   'ID'          => '1208221',
                'Name'        => 'Waste-WHITES-120822',
                'RecordStamp' => {},
            },
        ],

        # 'BULKY WASTE' workpack
        '2022-08-19T00:00:00' => [
            {   'ID'          => '1908221',
                'Name'        => 'Waste-BULKY WASTE-190822',
                'RecordStamp' => {},
            },
        ],

        # Both 'WHITES' & 'BULKY WASTE'
        '2022-08-26T23:59:59' => [
            {   'ID'          => '2608221',
                'Name'        => 'Waste-BULKY WASTE-260822',
                'RecordStamp' => {},
            },
            {   'ID'          => '2608222',
                'Name'        => 'Waste-WHITES-260822',
                'RecordStamp' => {},
            },
        ],

        # Both 'WHITES' & 'BULKY WASTE' but wrong/bad date in 'Name' - so
        # job counts for these collections are ignored
        '2022-09-02T00:00:00' => [
            {   'ID'   => '209221',
                'Name' => 'Waste-BULKY WASTE-010122',    # Non-matching date
                'RecordStamp' => {},
            },
            {   'ID'          => '209222',
                'Name'        => 'Waste-WHITES-20922',    # Bad format
                'RecordStamp' => {},
            },
            {   'ID'          => '209223',
                'Name'        => 'Waste-WHITES-311322',    # Impossible date
                'RecordStamp' => {},
            },
        ],

        # Workpacks with jobs that do not exceed the bulky limit:

        '2022-09-09T00:00:00' => [
            {   'ID'          => '909221',
                'Name'        => 'Waste-BULKY WASTE-090922',
                'RecordStamp' => {},
            },
        ],

        '2022-09-16T00:00:00' => [
            {   'ID'          => '1609221',
                'Name'        => 'Waste-WHITES-160922',
                'RecordStamp' => {},
            },
        ],

        '2022-09-23T00:00:00' => [
            {   'ID'          => '2309221',
                'Name'        => 'Waste-BULKY WASTE-230922',
                'RecordStamp' => {},
            },
            {   'ID'          => '2309222',
                'Name'        => 'Waste-WHITES-230922',
                'RecordStamp' => {},
            },
        ],

        # Workpacks with no jobs:

        '2022-09-30T00:00:00' => [
            {   'ID'          => '3009221',
                'Name'        => 'Waste-BULKY WASTE-300922',
                'RecordStamp' => {},
            },
            {   'ID'          => '3009222',
                'Name'        => 'Waste-WHITES-300922',
                'RecordStamp' => {},
            },
        ],

        '2022-10-07T00:00:00' => [
            {   'ID'          => '710221',
                'Name'        => 'Waste-BULKY WASTE-071022',
                'RecordStamp' => {},
            },
        ],
    };
}

sub _jobs_by_workpack_id {
    {
        # Not a bulky workpack so limit ignored
        508221 => _jobs_arrayref(40),

        # 'WHITES' - max jobs
        1208221 => _jobs_arrayref(40),

        # 'BULKY WASTE' - max jobs
        1908221 => _jobs_arrayref(40),

        # 'WHITES' & 'BULKY WASTE' that together make max jobs
        2608221 => _jobs_arrayref(10),
        2608222 => _jobs_arrayref( 30, 20001 ),

        # Connected to faulty workpack names so limit ignored
        209221 => _jobs_arrayref(40),
        209222 => _jobs_arrayref(40),
        209223 => _jobs_arrayref(40),

        # Limit not reached:

        # Same UPRN for all jobs so counts as single bulky collection
        909221 => [ ( { Job => { UPRN => 10001 } } ) x 40 ],

        1609221 => _jobs_arrayref(39),

        3009221 => _jobs_arrayref(25),
        # Same UPRN for all jobs so counts as single bulky collection
        3009222 => [ ( { Job => { UPRN => 10001 } } ) x 15 ],
    };
}

sub _jobs_arrayref {
    my ( $job_count, $uprn ) = @_;
    $uprn //= 10001;
    return [ map { { Job => { UPRN => $uprn++ } } } 1 .. $job_count ];
}

done_testing;
