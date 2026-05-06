import math
import wave
import struct
import os

# Ensure directory exists
os.makedirs("android/app/src/main/res/raw", exist_ok=True)

# Audio parameters
sample_rate = 44100
duration = 1.5 # seconds

# Frequencies for C major arpeggio (C5, E5, G5, C6) - Sounds like a success/level-up!
notes = [523.25, 659.25, 783.99, 1046.50]
note_duration = 0.15 # seconds per note

def generate_wave():
    audio = []
    
    # Generate arpeggio
    for i, freq in enumerate(notes):
        num_samples = int(sample_rate * note_duration)
        for t in range(num_samples):
            # Time in seconds
            time = t / sample_rate
            # Simple envelope (fade out)
            envelope = math.exp(-3 * time / note_duration)
            # Sine wave
            sample = int(32767 * envelope * 0.5 * math.sin(2 * math.pi * freq * time))
            audio.append(sample)
            
    # Add a final sustained chord (C major)
    sustain_duration = duration - (len(notes) * note_duration)
    num_samples = int(sample_rate * sustain_duration)
    for t in range(num_samples):
        time = t / sample_rate
        # Envelope with slower fade
        envelope = math.exp(-2 * time / sustain_duration)
        
        # Mix the chord
        sample = 0
        for freq in notes:
            sample += math.sin(2 * math.pi * freq * time)
            
        sample = int(32767 * envelope * 0.15 * sample)
        audio.append(sample)

    with wave.open("android/app/src/main/res/raw/motivation.wav", "w") as w:
        w.setnchannels(1) # Mono
        w.setsampwidth(2) # 2 bytes per sample (16 bit)
        w.setframerate(sample_rate)
        for sample in audio:
            w.writeframes(struct.pack('<h', sample))

generate_wave()
print("WAV generated successfully.")
