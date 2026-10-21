extends TestSuite
## Debug placeholder.

func run() -> void:
	var s: CampaignStep = App.campaign.step("terminal/intro")
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as TerminalIntro
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	for i: int in range(0, 49, 4):
		var sp: float = float(i) / 48.0
		print("  wipe s=%.2f hand(right,up,fwd)=%s pos=%s board=%s" % [sp, seq.wipe_hand[i], seq.wipe_position(sp), seq.wipe_hand_on_board(sp)])
	print("  board middle %s, stand %s, t_walk %.2f t_corner %.2f" % [seq.board.middle, seq.stand, seq.t_walk, seq.t_corner])
	seq.queue_free()
	await tree.process_frame
