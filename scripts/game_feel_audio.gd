class_name GameFeelAudio
extends RefCounted

## Original, quiet one-shot material gestures. No files, music or ambient loop.
## Generate each deterministic mono PCM buffer once, then share the five streams.
const SAMPLE_RATE: int = 22050
const PEAK_LIMIT: float = 0.72
const KINDS: Array[String] = ["plant", "harvest", "wave_complete", "victory", "shot"]
const DURATIONS: Dictionary = {
	"plant":0.16, "harvest":0.44, "wave_complete":0.36,
	"victory":0.70, "shot":0.075,
}
static var _cache: Dictionary = {}


static func stream(kind: String) -> AudioStreamWAV:
	var key: String = "wave_complete" if kind == "wave" else kind
	if key not in KINDS: return null
	if not _cache.has(key): _cache[key] = _build_stream(key)
	return _cache[key]


static func _pluck(time: float, start: float, duration: float, frequency: float, strength: float) -> float:
	var local: float = time-start
	if local <= 0.0 or local >= duration: return 0.0
	var attack: float = smoothstep(0.0, 0.006, local)
	var release: float = smoothstep(0.0, 0.045, duration-local)
	var body: float = sin(TAU*frequency*local)
	body += 0.17*sin(TAU*frequency*2.01*local)*exp(-18.0*local)
	body += 0.055*sin(TAU*frequency*3.97*local)*exp(-28.0*local)
	return body*strength*attack*release*exp(-10.0*local)


static func _build_stream(kind: String) -> AudioStreamWAV:
	var duration: float = DURATIONS[kind]
	var count: int = ceili(duration*SAMPLE_RATE)
	var samples := PackedFloat64Array()
	samples.resize(count)
	var random := RandomNumberGenerator.new()
	random.seed = 49157+KINDS.find(kind)*19023
	var soft_noise: float = 0.0
	var sum: float = 0.0
	var window_sum: float = 0.0
	for index in range(count):
		var time: float = float(index)/SAMPLE_RATE
		var noise: float = random.randf_range(-1.0,1.0)
		soft_noise = lerpf(soft_noise,noise,0.12)
		var sample: float = 0.0
		match kind:
			"plant":
				# A damped low wooden body and a brief soft soil contact.
				var envelope: float = smoothstep(0.0,0.004,time)*smoothstep(0.0,0.04,duration-time)*exp(-29.0*time)
				var body: float = sin(TAU*(190.0*time-180.0*time*time))
				sample = (body*0.42+soft_noise*0.34)*envelope
			"harvest":
				# G-B-D, staggered mallet notes rather than a sustained alert.
				sample = _pluck(time,0.0,0.24,392.0,0.31)
				sample += _pluck(time,0.10,0.24,493.883,0.29)
				sample += _pluck(time,0.20,0.24,587.330,0.27)
			"wave_complete":
				sample = _pluck(time,0.0,0.23,329.628,0.30)
				sample += _pluck(time,0.13,0.23,392.0,0.31)
			"victory":
				# A short softly rolled major chord; the longest release is <1 s.
				sample = _pluck(time,0.0,0.52,261.626,0.20)
				sample += _pluck(time,0.045,0.52,329.628,0.18)
				sample += _pluck(time,0.09,0.52,392.0,0.17)
				sample += _pluck(time,0.135,0.52,523.251,0.13)
			"shot":
				# Filtered breath/wood, with little tonal content to avoid a
				# repeated electronic beep during a dense wave of shots.
				var envelope: float = smoothstep(0.0,0.002,time)*smoothstep(0.0,0.025,duration-time)*exp(-52.0*time)
				sample = (soft_noise*0.52+sin(TAU*135.0*time)*0.10)*envelope
		samples[index] = sample
		sum += sample
		window_sum += pow(sin(PI*float(index)/maxi(1,count-1)),2.0)
	# Remove DC with a smooth zero-ended correction. Subtracting a plain mean
	# would move the endpoints off zero and introduce a click at playback edges.
	var correction: float = sum/maxf(0.001,window_sum)
	var peak: float = 0.0
	for index in range(count):
		var window: float = pow(sin(PI*float(index)/maxi(1,count-1)),2.0)
		samples[index] -= correction*window
		peak = maxf(peak,absf(samples[index]))
	samples[0] = 0.0
	samples[count-1] = 0.0
	var gain: float = minf(1.0,PEAK_LIMIT/maxf(0.001,peak))
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for index in range(count):
		var sample: float = samples[index]*gain
		var quantized: int = clampi(roundi(sample*32767.0),-32767,32767)
		bytes.encode_s16(index*2,quantized)
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.stereo = false
	result.loop_mode = AudioStreamWAV.LOOP_DISABLED
	result.data = bytes
	return result
