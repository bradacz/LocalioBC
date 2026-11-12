"""Finder layout consumed by dmgbuild; paths are provided by build-dmg.sh."""
import os

application = defines["app"]
format = "UDZO"
filesystem = "HFS+"
files = [application]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(application, "Contents", "Resources", "AppIcon.icns")
background = defines["background"]
window_rect = ((160, 120), (640, 420))
icon_locations = {"LocalioBC.app": (160, 208), "Applications": (480, 208)}
icon_size = 112
text_size = 13
arrange_by = None
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
include_icon_view_settings = True
include_list_view_settings = False
# Do not add FinderInfo to the signed app after codesigning.
hide_extensions = []
