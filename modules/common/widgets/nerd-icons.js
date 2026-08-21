.pragma library

function nerdIcon(name) {
    switch (name) {
        case "key": return "\uDB80\uDF06";
        case "key_off": return "\uDB83\uDDD6";
        case "device_thermostat": return "\uF2C9";
        case "token": return "\uDB82\uDC30";
        case "arrow_upward": return "\uDB80\uDF11";
        case "arrow_downward": return "\uF063";
        case "neurology": return "\uEE9C";
        case "robot": return "\uDB81\uDEA9";
        case "person": return "\uF007";
        case "settings": return "\uF013";
        case "computer": return "\uF108";
        case "visibility_off": return "\uF4C5";
        case "refresh": return "\uEAD2";
        case "content_copy": return "\uEBCC";
        case "inventory": return "\uF05D";
        case "edit": return "\uEA73";
        case "code": return "\uF121";
        case "close": return "\uF00D";
        case "search": return "\uF002";
        case "api": return "\uDB84\uDC9B";
        case "service_toolbox": return "\uEE1B";
        case "attach_file": return "\uDB80\uDC66";
        case "save": return "\uDB80\uDD93";
        case "check": return "\uF00C";
        case "linked_services": return "\uEB15";
        case "keyboard_arrow_down": return "\uF078";
        case "image": return "\uDB80\uDE1F";
        case "music_note": return "\uDB80\uDE23";
        case "movie": return "\uDB80\uDE2B";
        case "picture_as_pdf": return "\uF1C1";
        case "description": return "\uDB80\uDE19";
        case "file_present": return "\uDB80\uDE14";
        default: return name;
    }
}
