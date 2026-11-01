"""Render GameAudio.swift's original voices/envelopes to Android PCM assets."""
from pathlib import Path
import math, re, struct, wave
root = Path(__file__).resolve().parents[2]
source = (root / 'Packages/GameShell/Sources/GameShell/GameAudio.swift').read_text()
source = source[source.index('        switch key {'):source.index('        if let buffer {')]
sections = re.split(r'        case \.', source)[1:]
out = root / 'android/app/src/main/res/raw'
for section in sections:
    name = section.split(':', 1)[0].split('(')[0]
    variants = [(f'selected_{i+1}', freq) for i, freq in enumerate([440, 554.37, 659.25])] if name == 'cardSelected' else [(re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower(), None)]
    for filename, freq in variants:
        text = section
        if freq is not None:
            text = text.replace('frequency: frequency * 2', f'frequency: {freq*2}').replace('frequency: frequency,', f'frequency: {freq},')
        duration = float(re.search(r'makeBuffer\(duration: ([\d.]+)', text)[1])
        voices = []
        for definition in re.findall(r'Voice\((.*?)\)', text, re.S):
            v = dict(attack=.008, release=.06, vibratoDepth=0., vibratoRate=5., waveform='sine')
            for key, value in re.findall(r'(\w+):\s*([.\w]+)', definition):
                v[key] = value.lstrip('.') if key == 'waveform' else float(value)
            voices.append(v)
        noise = 0x4D595DF4D0F33173
        frames = bytearray()
        for frame in range(int(duration * 44100)):
            time = frame / 44100
            sample = 0.
            for v in voices:
                if not v['start'] <= time < v['start'] + v['duration']: continue
                t = time - v['start']
                attack = min(v['attack'], v['duration']*.35)
                release = min(v['release'], v['duration']*.45)
                envelope = max(0, min(min(1,t/attack) if attack else 1, min(1,(v['duration']-t)/release) if release else 1))
                frequency = v['frequency'] + v['vibratoDepth']*math.sin(2*math.pi*v['vibratoRate']*t)
                phase = 2*math.pi*frequency*t
                if v['waveform']=='noise':
                    noise = (noise*2862933555777941757+3037000493) & ((1<<64)-1)
                    value = ((noise>>40)/(1<<24))*2-1
                elif v['waveform']=='triangle': value = 2*abs(2*(phase/(2*math.pi)-math.floor(phase/(2*math.pi)+.5)))-1
                else: value = math.sin(phase)
                sample += value * v['amplitude'] * envelope
            sample=max(-.95,min(.95,sample))
            frames += struct.pack('<hh', round(sample*32767), round(sample*.98*32767))
        with wave.open(str(out / (filename+'.wav')), 'wb') as f:
            f.setnchannels(2); f.setsampwidth(2); f.setframerate(44100); f.writeframes(frames)
