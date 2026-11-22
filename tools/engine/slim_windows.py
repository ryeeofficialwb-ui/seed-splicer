# Godot 4.7.2 build profile for Seed Splicer's slim Windows release template.
#
# Seed Splicer is a 2D UI game on the Compatibility (OpenGL) renderer, so 3D,
# physics, navigation, XR, Vulkan/D3D12, and editor-only importers are left out.
# Rebuild with tools/engine/build_template.ps1 (see the header there).

platform = "windows"
arch = "x86_64"
target = "template_release"
production = "yes"
optimize = "size"
lto = "full"
debug_symbols = "no"

# Renderers: Compatibility (OpenGL 3) only.
vulkan = "no"
d3d12 = "no"
opengl3 = "yes"

# Engine features the game never uses.
disable_3d = "yes"
disable_physics_2d = "yes"
disable_physics_3d = "yes"
disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_xr = "yes"
accesskit = "no"  # screen-reader bridge
sdl = "no"  # gamepad input

# Modules: everything off except what the game needs.
modules_enabled_by_default = "no"
module_gdscript_enabled = "yes"
module_freetype_enabled = "yes"
module_text_server_fb_enabled = "yes"  # lightweight text engine (no ICU/HarfBuzz)
module_svg_enabled = "yes"  # default theme icons (checkboxes, arrows) are SVG
module_webp_enabled = "yes"  # lossless imported textures
module_regex_enabled = "yes"
module_ogg_enabled = "yes"  # music
module_vorbis_enabled = "yes"
module_mbedtls_enabled = "yes"  # HTTPS for online features and the updater
