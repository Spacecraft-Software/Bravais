# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Audio Configuration (PipeWire)
{
  ...
}:

{
  # Disable PulseAudio (replaced by PipeWire)
  services.pulseaudio.enable = false;

  # Enable PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true; # Uncomment for JACK support
  };
}
