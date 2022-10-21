(function(){

if (!fixmystreet.maps) {
    return;
}

var wfs_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var tilma_url = "https://" + wfs_host + "/mapserver/thamesmead";
var wfs_url = "https://maps.peabody.org.uk/getows.ashx?mapsource=mapsources/maplayers";

var defaults = {
    http_wfs_url: wfs_url,
    asset_type: 'area',
    geometryName: 'msGeometry',
    srsName: "EPSG:27700",
    non_interactive: true,
    road: true,
    display_zoom_message: true,
    nearest_radius: 0.1,
    body: "Thamesmead",
    asset_item_message: 'Please pick a highlighted area from the map to report an issue to Thamesmead/Peabody.',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "hardsurfaces",
    no_asset_msg_id: '#js-not-an-asset-hard-surfaces',
    asset_item: 'Thamesmead managed hard surface',
    asset_group: 'Hard surfaces/paths/road (Peabody)'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "grass",
    no_asset_msg_id: '#js-not-an-asset-grass',
    asset_item: 'Thamesmead managed grass area',
    asset_group: 'Grass and grass areas (Peabody)'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "water",
    no_asset_msg_id: '#js-not-an-asset-water',
    asset_item: 'Thamesmead managed water area',
    asset_group: 'Water areas (Peabody)'
});

fixmystreet.assets.add(defaults, {
    http_wfs_url: tilma_url,
    wfs_feature: "treegroups",
    no_asset_msg_id: '#js-not-an-asset-trees',
    asset_item: 'Thamesmead managed trees area',
    asset_group: 'Trees (Peabody)'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "planting",
    no_asset_msg_id: '#js-not-an-asset-planters',
    asset_item: 'Thamesmead managed shrubs area',
    asset_group: 'Planters and flower beds (Peabody)'
});

})();
