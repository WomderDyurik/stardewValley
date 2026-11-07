extends SceneTree

## Signal checks only: this fixture never creates an audio player or plays sound.
const Audio = preload("res://scripts/game_feel_audio.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var fingerprints: Dictionary = {}
	for kind in Audio.KINDS:
		var sound: AudioStreamWAV = Audio.stream(kind)
		expect(sound != null,kind+" has a generated event stream")
		if sound == null: continue
		expect(sound == Audio.stream(kind),kind+" reuses the cached stream")
		expect(sound.format == AudioStreamWAV.FORMAT_16_BITS and sound.mix_rate == 22050 and not sound.stereo,kind+" is mono PCM16 at 22050 Hz")
		expect(sound.loop_mode == AudioStreamWAV.LOOP_DISABLED,kind+" cannot start an ambient loop")
		var bytes: PackedByteArray = sound.data
		var count: int = bytes.size()/2
		expect(bytes.size()%2 == 0 and count > 0,kind+" contains complete PCM16 samples")
		expect(absf(sound.get_length()-float(Audio.DURATIONS[kind])) < 1.0/Audio.SAMPLE_RATE,kind+" has the authored short duration")
		expect(bytes == Audio._build_stream(kind).data,kind+" is deterministic even when regenerated")
		var all_finite: bool = true
		var peak: float = 0.0
		var sum: float = 0.0
		var energy: float = 0.0
		var tail_energy: float = 0.0
		var tail_start: int = maxi(0,count-220) # Last 10 ms must release quietly.
		for index in range(count):
			var sample: float = float(bytes.decode_s16(index*2))/32768.0
			all_finite = all_finite and is_finite(sample)
			peak = maxf(peak,absf(sample))
			sum += sample
			energy += sample*sample
			if index >= tail_start: tail_energy += sample*sample
		expect(all_finite,kind+" contains only finite samples")
		expect(peak <= 0.721 and peak < 0.8,kind+" stays below the safe peak with no clipping")
		expect(peak > 0.02 and energy/count > 0.00001,kind+" is a real nonempty audio gesture")
		expect(absf(sum/count) < 0.0001,kind+" has negligible DC offset")
		expect(bytes.decode_s16(0) == 0 and bytes.decode_s16(bytes.size()-2) == 0,kind+" starts and ends at zero")
		expect(sqrt(tail_energy/maxi(1,count-tail_start)) < 0.012,kind+" releases without an abrupt sustained tail")
		var fingerprint: int = hash(bytes)
		expect(not fingerprints.has(fingerprint),kind+" has a distinct signal")
		fingerprints[fingerprint] = true
	expect(Audio.stream("wave") == Audio.stream("wave_complete"),"wave alias shares the completion cache entry")
	expect(Audio.stream("unknown") == null and Audio._cache.size() == 5,"unknown events create no sound and the cache has exactly five streams")
	print("Game feel audio: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
