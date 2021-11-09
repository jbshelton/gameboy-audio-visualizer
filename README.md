# Gameboy Audio Visualizer
I built this project off of an in\-development version of GBAudioPlayerV3, for the purpose of challenging myself and to make an idea that I've had for a while come to life\.
I have not touched it in quite a while, so there's a good chance that the code is somewhat incomplete\.
That said, I probably won't come back to update the code any time soon, because I have moved on from my audio player in general for now\.

---

### What it does \(or did\)
This audio visualizer that I made takes either 8\-bit audio or specially encoded audio that can be written to the Gameboy's sound registers directly, plays it back in high quality, and displays the waveform on the screen vertically\. The Gameboy barely has enough time to play back the audio and display the waveform on the screen\- getting this to work was challenging\!
It uses lookup tables to play back the audio and to keep the interrupts going to display the waveform\(s\) on screen\.