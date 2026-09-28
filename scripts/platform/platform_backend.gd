class_name PlatformBackend
extends RefCounted
## One platform's implementation of the Platform interface (Steam, Google Play, App Store, ...).
## The base class does nothing and reports every service as unavailable; each platform overrides
## what it supports. Methods that wait on the platform (ads, purchases, cloud load) are coroutines:
## callers `await` them.
##
## Real backends (Steam, AdMob/Play Billing, Game Center/StoreKit) are DESIGN-TBD until risk test
## R3 picks the plugins (docs/NEXT_STEPS.md).


func backend_name() -> String:
	return "none"


func ads_available() -> bool:
	return false


## Shows a rewarded ad. True if the player watched it to the end and earned the reward.
func show_rewarded_ad(_placement: StringName) -> bool:
	return false


func purchases_available() -> bool:
	return false


## Products for sale: [{id, title, price_text, credits}].
func products() -> Array[Dictionary]:
	return []


## Buys a product. True if the purchase completed.
func purchase(_product_id: StringName) -> bool:
	return false


func leaderboards_available() -> bool:
	return false


func submit_score(_board: String, _score: int) -> void:
	pass


func show_leaderboard(_board: String) -> void:
	pass


func unlock_achievement(_id: String) -> void:
	pass


## Opens a page outside the game, such as a store page (the web demo's "get the full game" screen,
## GDD §2). True if the platform opened it. On the web this opens a new browser tab; a portal whose
## rules restrict outbound links gets a backend of its own that says no here.
func open_url(url: String) -> bool:
	return OS.shell_open(url) == OK


func cloud_save_available() -> bool:
	return false


func cloud_save(_data: String) -> void:
	pass


func cloud_load() -> String:
	return ""
