(function(){

if (!fixmystreet.maps) {
    return;
}

var domain = fixmystreet.staging ? "https://tilma.staging.mysociety.org" : "https://tilma.mysociety.org";
var defaults = {
    http_wfs_url: domain + "/mapserver/centralbeds",
    asset_type: 'spot',
    max_resolution: 9.554628534317017,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    body: "Central Bedfordshire Council"
};
var proxy_defaults = $.extend(true, {}, defaults, {
    http_options: {
        url: domain + "/proxy/cbc/wfs",
        params: {
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    srsName: "EPSG:27700"
});

var centralbeds_types = [
    "CBC",
    "Fw",
];

function likely_trees_report() {
    // Ensure the user can select anywhere on the map if they want to
    // make a report in the "Trees" category. This means we don't show the
    // "not found" message if no category/group has yet been selected
    // or if only the group containing the "Trees" category has been
    // selected.
    var selected = fixmystreet.reporting.selectedCategory();
    return selected.category === "Trees" ||
            (selected.group === "Grass, Trees, Verges and Weeds" && !selected.category) ||
            (!selected.group && !selected.category);
}

function show_non_stopper_message() {
    // For reports about trees on private roads, Central Beds want the
    // "not our road" message to be shown and also for the report to be
    // able to be made.
    // The existing stopper message code doesn't allow for this situation, so
    // this function is used to show a custom DOM element that contains the
    // message.
    if ($('html').hasClass('mobile')) {
        var msg = $("#js-custom-not-council-road").html();
        $div = $('<div class="js-mobile-not-an-asset"></div>').html(msg);
        $div.appendTo('#map_box');
    } else {
        $("#js-custom-roads-responsibility").removeClass("hidden");
    }
}

function hide_non_stopper_message() {
    $('.js-mobile-not-an-asset').remove();
    $("#js-custom-roads-responsibility").addClass("hidden");
}

fixmystreet.assets.add(defaults, {
    wfs_feature: "Highways",
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    road: true,
    all_categories: true,
    usrn: {
        attribute: 'streetref1',
        field: 'NSGRef'
    },
    actions: {
        found: function(layer, feature) {
            fixmystreet.message_controller.road_found(layer, feature, function(feature) {
                hide_non_stopper_message();
                if (OpenLayers.Util.indexOf(centralbeds_types, feature.attributes.adoption) != -1) {
                    return true;
                }
                if (likely_trees_report()) {
                    show_non_stopper_message();
                    return true;
                }
                return false;
            }, "#js-not-council-road");
        },
        not_found: function(layer) {
            hide_non_stopper_message();
            if (likely_trees_report()) {
                fixmystreet.message_controller.road_found(layer);
            } else {
                fixmystreet.message_controller.road_not_found(layer);
            }
        }
    },
    asset_item: "road",
    asset_type: 'road',
    no_asset_msg_id: '#js-not-a-road',
    no_asset_msgs_class: '.js-roads-centralbeds',
    name: "Highways"
});

var streetlight_stylemap = new OpenLayers.StyleMap({
    'default': fixmystreet.assets.style_default,
    'hover': fixmystreet.assets.style_default_hover,
    'select': fixmystreet.assets.construct_named_select_style("${lighting_c}")
});

var labeled_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    stylemap: streetlight_stylemap,
    feature_code: 'lighting_c',
    asset_id_field: 'asset',
    attributes: {
        UnitID: 'asset'
    },
    actions: {
        asset_found: fixmystreet.assets.named_select_action_found,
        asset_not_found: fixmystreet.assets.named_select_action_not_found
    }
});

fixmystreet.assets.add(labeled_defaults, {
    wfs_feature: "StreetLighting",
    max_resolution: 2.388657133579254,
    asset_category: ["Street Lights"],
    asset_item: 'street light'
});

fixmystreet.assets.add(defaults, {
    wfs_feature: "Gullies",
    max_resolution: 1.194328566789627,
    asset_category: ["Surface cover", "Drains/Ditches Blocked"],
    asset_item: 'drain or manhole'
});

fixmystreet.assets.add(proxy_defaults, {
    http_options: {
        params: {
            propertyName: 'id,msGeometry',
            TYPENAME: "trees"
        }
    },
    asset_id_field: 'id',
    attributes: {
        UnitID: 'id'
    },
    max_resolution: 1.194328566789627,
    asset_category: ["Trees"],
    asset_item: 'tree'
});


})();
