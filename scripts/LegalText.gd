class_name LegalText
## Who makes the game, and where its legal pages live.
## The Anant Originals website is the master copy of the Privacy Policy, Terms of Use,
## Privacy Rights and Privacy Preferences for all our games. The game opens those pages
## in the browser instead of carrying its own copy of the text.

const DEVELOPER := "Anant Originals"
const CONTACT_EMAIL := "contact.anantoriginals@gmail.com"
const MIN_AGE := 18  # matches the Play Console target audience (18+ only)

## The live Anant Originals website (www, because the bare domain redirects there).
const WEBSITE := "https://www.anantoriginals.com"

const PAGES := {
	"privacy_policy": "/privacy#arrow-crush",
	"terms": "/terms",
	"privacy_rights": "/privacy-rights",
	"privacy_prefs": "/privacy-preferences",
	"legal": "/legal",
	"contact": "/contact",
	"licenses": "/licenses",
	"game": "/games/arrow-crush",
}


## Full web address of one of the pages above.
static func url(page: String) -> String:
	return WEBSITE + str(PAGES.get(page, "/legal"))


## Opens one of the website's legal pages in the phone's browser.
static func open_page(page: String) -> void:
	OS.shell_open(url(page))
