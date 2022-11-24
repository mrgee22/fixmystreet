use JSON::MaybeXS;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest "check translation endpoint" => sub {
    $mech->get_ok('/js/translation_strings.en-gb.js');
    $mech->content_contains('translation_strings');
};

subtest "check asset layer endpoint" => sub {
    $mech->get_ok('/js/asset_layers.js');
    $mech->content_is('var fixmystreet = fixmystreet || {}; (function(){ if (!fixmystreet.maps) { return; } fixmystreet.asset_layers = {}; var defaults; })();' . "\n");

    my $defaults = { wfs_url => 'http://example.org', geometryName => 'msGeometry', srsName => 'EPSG:3857' };
    my $bridges = { wfs_feature => 'Bridges', asset_item => 'bridge', asset_category => 'Bridges' };

    foreach ('fixmystreet', 'lincolnshire', 'greenwich') {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $_,
            COBRAND_FEATURES => { asset_layers => { lincolnshire => [ [ $defaults ], $bridges ] } },
        }, sub {
            $mech->get_ok('/js/asset_layers.js');
            my $content = $mech->encoded_content;
            $content =~ /defaults = (\{.*?\}\})/;
            return unless $1;
            my $json = decode_json($1);
            is_deeply $json, { default => $defaults };
            $content =~ /fixmystreet\.assets\.add\(defaults\.default, (\{.*?\})\);/;
            $json = decode_json($1);
            is_deeply $json, $bridges;
        };
    }
};

done_testing();
