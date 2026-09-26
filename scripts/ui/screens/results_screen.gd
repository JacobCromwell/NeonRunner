class_name ResultsScreen
extends Control
## After a run: level complete (stars, score, credits, stats) or the run summary after a death
## (credits kept). Then on to the shop and the next level or a retry (GDD §4, §8).
## DESIGN-TBD: which stats the level-complete screen shows (OPEN_QUESTIONS §5). Placeholder look.

var result: RunResult


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 560.0)
	var ctx: RunContext = result.context
	if result.completed:
		ScreenKit.title(col, "LEVEL COMPLETE", 40)
		var stars: Label = ScreenKit.label(col, "*".repeat(result.stars) + "-".repeat(3 - result.stars), 36)
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		ScreenKit.title(col, "RUN OVER", 40)
		ScreenKit.label(col, "Hit by: %s" % result.cause, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lines: PackedStringArray = []
	lines.append("Score: %d%s" % [result.score, "   NEW BEST!" if result.record.get("new_best", false) else ""])
	if result.completed:
		lines.append("Credits: %d collected + %d bonus = %d" % [result.credits_collected, result.completion_bonus, result.credits_earned])
	else:
		lines.append("Credits: kept %d of %d collected" % [result.credits_earned, result.credits_collected])
	var st: Dictionary = result.stats
	lines.append("Time: %.1f s   Distance: %d m" % [result.time, result.distance])
	lines.append("Kills: %d   Stomps: %d   Ramps: %d" % [st.get("kills", 0), st.get("stomps", 0), st.get("ramps", 0)])
	lines.append("Longest wall run: %.0f m   Hits blocked: %d" % [st.get("longest_wall_run", 0.0), st.get("blocked", 0)])
	ScreenKit.label(col, "\n".join(lines), 18)
	var r: HBoxContainer = ScreenKit.row(col)
	ScreenKit.button(r, "Continue", func() -> void: App.continue_after_result(result))
	if not result.completed or ctx.mode != RunContext.Mode.CAMPAIGN:
		ScreenKit.button(r, "Retry now", func() -> void: App.retry(ctx))
	ScreenKit.button(r, "Menu", App.show_level_select if ctx.is_campaign() else App.show_title)
	ScreenKit.focus_first(self)
