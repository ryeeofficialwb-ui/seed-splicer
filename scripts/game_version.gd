class_name GameVersion
extends RefCounted
## The game's version, and where its updates come from. tools/publish_update.py sets VERSION when it
## publishes an update; don't change it by hand unless you're publishing.
## Numbering: the first official release is Indev 0.1. The test releases before it were renamed
## 0.0.1 - 0.0.4 (they were published as 1.0.1 - 1.0.4 and are hidden on GitHub now).

const STAGE := "Indev"  ## shown before the number: "Indev 0.1"
const VERSION := "0.1.1"
## The GitHub repository whose Releases hold the update packs (SeedSplicer-<version>.pck plus its
## .sha256). It must be PUBLIC: players' games download from it without logging in.
const RELEASES_REPO := "ryeeofficialwb-ui/seed-splicer"


## "Indev 0.1": how the version is shown (the corner of the screen, sign-in, Statistics, releases).
static func label(version := VERSION) -> String:
	return "%s %s" % [STAGE, version]


## Is version `a` newer than `b`? ("1.10.0" > "1.9.2"; a missing part counts as 0.)
static func is_newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
