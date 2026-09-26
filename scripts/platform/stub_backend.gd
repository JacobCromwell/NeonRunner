class_name StubBackend
extends PlatformBackend
## The stand-in backend for the editor, tests and the web demo (CLAUDE.md principle 5). It can
## simulate the mobile services so their flows can be played on a desktop: a fake rewarded ad
## (a short wait, then the reward), fake purchases that always succeed, and leaderboards kept in
## memory. The web demo uses it with everything off (GDD §2: no ads, purchases or leaderboards).

## DESIGN-TBD: the in-app purchase catalogue (OPEN_QUESTIONS §7). Placeholder credit packs.
const FAKE_PRODUCTS: Array[Dictionary] = [
	{"id": &"credits_small", "title": "Credit pack", "price_text": "$0.99", "credits": 1000},
	{"id": &"credits_large", "title": "Credit crate", "price_text": "$4.99", "credits": 6000},
]

var simulate_ads: bool = false
var simulate_purchases: bool = false
var simulate_leaderboards: bool = false
## How long the fake ad "plays" (seconds). Tests set 0.
var fake_ad_seconds: float = 1.0
## Scores submitted, by board (simulated leaderboards).
var scores: Dictionary = {}
var achievements: PackedStringArray = []
var tree: SceneTree


func backend_name() -> String:
	return "stub"


func ads_available() -> bool:
	return simulate_ads


func show_rewarded_ad(placement: StringName) -> bool:
	if not simulate_ads:
		return false
	print("[Platform stub] rewarded ad for '%s'" % placement)
	if fake_ad_seconds > 0.0 and tree != null:
		await tree.create_timer(fake_ad_seconds, true).timeout
	return true


func purchases_available() -> bool:
	return simulate_purchases


func products() -> Array[Dictionary]:
	return FAKE_PRODUCTS.duplicate(true) if simulate_purchases else []


func purchase(product_id: StringName) -> bool:
	if not simulate_purchases:
		return false
	for p: Dictionary in FAKE_PRODUCTS:
		if p["id"] == product_id:
			print("[Platform stub] purchased '%s'" % product_id)
			return true
	return false


func leaderboards_available() -> bool:
	return simulate_leaderboards


func submit_score(board: String, score: int) -> void:
	if simulate_leaderboards:
		scores[board] = maxi(int(scores.get(board, 0)), score)


func unlock_achievement(id: String) -> void:
	if not achievements.has(id):
		achievements.append(id)
